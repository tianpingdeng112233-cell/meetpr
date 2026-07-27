import SwiftUI

public struct ExerciseSetRecord: Equatable, Sendable {
  public let index: Int
  public let weight: Double?
  public let reps: Int
  public let rpe: Double
  public let status: SetRow.Status
  public let videoState: SetRow.VideoState

  public init(
    index: Int,
    weight: Double?,
    reps: Int,
    rpe: Double,
    status: SetRow.Status,
    videoState: SetRow.VideoState
  ) {
    self.index = index
    self.weight = weight
    self.reps = reps
    self.rpe = rpe
    self.status = status
    self.videoState = videoState
  }
}

/// Expandable exercise receipt defined by `ExerciseCard.dc.html`.
@MainActor
public struct ExerciseCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rollProgress: CGFloat
  @State private var showsCollapsedRepresentation: Bool
  @State private var collapsedHeaderHeight: CGFloat = 0
  @State private var rollTask: Task<Void, Never>?

  let exercise: String
  let meta: String
  let note: String
  let collapsed: Bool
  let sets: [ExerciseSetRecord]
  private let onToggle: @MainActor (Bool) -> Void
  private let onEditSet: @MainActor (ExerciseSetRecord) -> Void
  private let onVideoAction: @MainActor (ExerciseSetRecord) -> Void

  public init(
    exercise: String,
    meta: String,
    note: String,
    collapsed: Bool,
    sets: [ExerciseSetRecord],
    onToggle: @escaping @MainActor (Bool) -> Void = { _ in },
    onEditSet: @escaping @MainActor (ExerciseSetRecord) -> Void = { _ in },
    onVideoAction: @escaping @MainActor (ExerciseSetRecord) -> Void = { _ in }
  ) {
    self.exercise = exercise
    self.meta = meta
    self.note = note
    self.collapsed = collapsed
    self.sets = sets
    self.onToggle = onToggle
    self.onEditSet = onEditSet
    self.onVideoAction = onVideoAction
    self._rollProgress = State(initialValue: collapsed ? 1 : 0)
    self._showsCollapsedRepresentation = State(initialValue: collapsed)
  }

  public var body: some View {
    ExerciseCardWidthLayout(
      widthFraction: showsCollapsedRepresentation
        ? ExerciseCardContract.collapsedWidthFraction
        : 1
    ) {
      ZStack(alignment: .top) {
        expandedCard
          .modifier(
            RollUpCollapseModifier(
              progress: effectiveRollProgress,
              collapsedHeight: collapsedHeaderHeight
            )
          )
          .allowsHitTesting(!showsCollapsedRepresentation)
          .accessibilityHidden(showsCollapsedRepresentation)

        collapsedCard
          .opacity(showsCollapsedRepresentation ? 1 : 0)
          .allowsHitTesting(showsCollapsedRepresentation)
          .accessibilityHidden(!showsCollapsedRepresentation)
          .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
          } action: { height in
            collapsedHeaderHeight = height
          }
      }
    }
    // motion/03 line 31: collapsed width uses 280ms
    // cubic-bezier(.22,.61,.36,1).
    .animation(
      reduceMotion
        ? nil
        : .timingCurve(
          MeetPRMotion.easeOutX1,
          MeetPRMotion.easeOutY1,
          MeetPRMotion.easeOutX2,
          MeetPRMotion.easeOutY2,
          duration: 0.28
        ),
      value: showsCollapsedRepresentation
    )
    .onChange(of: collapsed) { _, newValue in
      animateCollapse(to: newValue)
    }
    .onChange(of: reduceMotion) { _, newValue in
      guard newValue else { return }
      finishRollWithoutAnimation()
    }
    .onDisappear {
      rollTask?.cancel()
    }
  }

  private var expandedCard: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      exerciseHeader(open: true, rollProgress: effectiveRollProgress)

      VStack(spacing: MeetPRSpacing.zero) {
        columnHeaders

        ForEach(sets.indices, id: \.self) { index in
          let set = sets[index]
          SetRow(
            index: set.index,
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe,
            status: set.status,
            videoState: set.videoState,
            onEdit: { onEditSet(set) },
            onVideoAction: { onVideoAction(set) }
          )
        }

        if !note.isEmpty {
          Text(note)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .lineSpacing(MeetPRSpacing.point7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MeetPRSpacing.space4)
            .padding(.vertical, MeetPRSpacing.point11)
        }
      }
      // motion/03 lines 65-69: only `#body` receives the four 3D keyframes.
      // The header remains stable while the outer height and meta collapse.
      .modifier(RollUpBodyModifier(progress: effectiveRollProgress))
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: ExerciseCardContract.expandedRadius))
    .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
  }

  private func exerciseHeader(open: Bool, rollProgress: CGFloat = 0) -> some View {
    ExerciseCardHeader(
      exercise: exercise,
      meta: meta,
      allRecorded: allRecorded,
      progressText: progressText,
      summaryText: summaryText,
      open: open,
      rollProgress: rollProgress,
      action: toggle
    )
  }

  private var collapsedCard: some View {
    exerciseHeader(open: false)
      .background(Color.MeetPR.bgStack)
      .clipShape(.rect(cornerRadius: ExerciseCardContract.collapsedRadius))
      .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
  }

  private var columnHeaders: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      Text("#").frame(width: 22, alignment: .leading)
      Text("重量").frame(maxWidth: .infinity, alignment: .leading)
      Text("次数").frame(maxWidth: .infinity)
      Text("RPE").frame(maxWidth: .infinity)
      Color.MeetPR.bgBase.opacity(0).frame(width: 64)
    }
    .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
    .tracking(0.5)
    .foregroundStyle(Color.MeetPR.textDim)
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point6)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
  }

  private var completedSets: [ExerciseSetRecord] {
    sets.filter { $0.status == .done || $0.status == .failed }
  }

  private var allRecorded: Bool {
    !sets.isEmpty && completedSets.count == sets.count
  }

  private var progressText: String {
    "\(completedSets.count) / \(sets.count) 组已记录"
  }

  private var summaryText: String {
    Self.summaryText(for: sets)
  }

  static func summaryText(for sets: [ExerciseSetRecord]) -> String {
    let completedSets = sets.filter { $0.status == .done || $0.status == .failed }
    // Mockup `exSummary`: no logged sets → empty string, not a 0/N counter.
    guard let last = completedSets.last else {
      return ""
    }
    let failedCount = completedSets.filter { $0.status == .failed }.count
    let failure = failedCount > 0 ? " · \(failedCount) 组未完成" : ""
    let weight = last.weight.map { "\(numberText($0))kg" } ?? "—"
    let prescription = "\(weight)×\(last.reps) @\(numberText(last.rpe))"
    return "\(completedSets.count) 组 · \(prescription)\(failure)"
  }

  private func toggle() {
    onToggle(collapsed)
  }

  private func animateCollapse(to isCollapsed: Bool) {
    rollTask?.cancel()
    if reduceMotion {
      finishRollWithoutAnimation()
      return
    }

    if !isCollapsed {
      // motion/03 lines 48 and 31-32: expanding switches the open DOM
      // immediately; only width/background retain their CSS transitions.
      var transaction = Transaction()
      transaction.animation = nil
      withTransaction(transaction) {
        rollProgress = 0
        showsCollapsedRepresentation = false
      }
      return
    }

    showsCollapsedRepresentation = false
    var resetTransaction = Transaction()
    resetTransaction.animation = nil
    withTransaction(resetTransaction) {
      rollProgress = 0
    }
    // motion/03 lines 64-73: all four roll keyframes and measured height
    // share 620ms cubic-bezier(.4,0,.2,1).
    withAnimation(MeetPRMotion.rollUp) {
      rollProgress = 1
    }
    rollTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(MeetPRMotion.durationRollUp))
      guard !Task.isCancelled else { return }
      showsCollapsedRepresentation = true
    }
  }

  private var effectiveRollProgress: CGFloat {
    reduceMotion ? (collapsed ? 1 : 0) : rollProgress
  }

  private func finishRollWithoutAnimation() {
    rollTask?.cancel()
    rollTask = nil
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) {
      rollProgress = collapsed ? 1 : 0
      showsCollapsedRepresentation = collapsed
    }
  }

  private static func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

enum ExerciseCardContract {
  static let collapsedWidthFraction: CGFloat = 0.92
  static let radius: CGFloat = 16
  static let expandedRadius = radius
  static let collapsedRadius: CGFloat = 14
  static let expandedNameSize: CGFloat = 16
  static let collapsedNameSize: CGFloat = 14
  static let expandedBarMinimumHeight: CGFloat = 26
  static let collapsedBarMinimumHeight: CGFloat = 18
  static let collapsedCaretRotation: Double = -90
}

private struct ExerciseCardWidthLayout: Layout {
  var widthFraction: CGFloat

  var animatableData: CGFloat {
    get { widthFraction }
    set { widthFraction = newValue }
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    guard let subview = subviews.first else { return .zero }
    let proposedWidth = proposal.width.map { $0 * widthFraction }
    let childSize = subview.sizeThatFits(
      ProposedViewSize(width: proposedWidth, height: proposal.height)
    )
    return CGSize(width: proposal.width ?? childSize.width, height: childSize.height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    guard let subview = subviews.first else { return }
    subview.place(
      at: bounds.origin,
      anchor: .topLeading,
      proposal: ProposedViewSize(
        width: bounds.width * widthFraction,
        height: bounds.height
      )
    )
  }
}

private let mixedExerciseSets = [
  ExerciseSetRecord(
    index: 1, weight: 175, reps: 3, rpe: 8.5, status: .done, videoState: .uploaded),
  ExerciseSetRecord(
    index: 2, weight: 175, reps: 3, rpe: 8.5, status: .failed, videoState: .failed),
  ExerciseSetRecord(
    index: 3, weight: 175, reps: 3, rpe: 8.5, status: .pending, videoState: .none),
]

private let finishedExerciseSets = [
  ExerciseSetRecord(
    index: 1, weight: 90, reps: 2, rpe: 6, status: .done, videoState: .uploaded),
  ExerciseSetRecord(
    index: 2, weight: 90, reps: 2, rpe: 6, status: .failed, videoState: .uploaded),
]

#Preview("ExerciseCard · Expanded + Summary · Dark") {
  VStack(spacing: MeetPRSpacing.point10) {
    ExerciseCard(
      exercise: "硬拉",
      meta: "上次 170kg×3 @8 · 最佳 175kg×3 @8.5",
      note: "注意启动时股四的蹬地",
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: "节奏卧推",
      meta: "上次 87.5kg×2 @6 · 最佳 90kg×2 @6",
      note: "",
      collapsed: true,
      sets: finishedExerciseSets
    )
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}
#Preview("ExerciseCard · Expanded + Summary · Light") {
  VStack(spacing: MeetPRSpacing.point10) {
    ExerciseCard(
      exercise: "硬拉",
      meta: "上次 170kg×3 @8 · 最佳 175kg×3 @8.5",
      note: "注意启动时股四的蹬地",
      collapsed: false,
      sets: mixedExerciseSets
    )
    ExerciseCard(
      exercise: "节奏卧推",
      meta: "上次 87.5kg×2 @6 · 最佳 90kg×2 @6",
      note: "",
      collapsed: true,
      sets: finishedExerciseSets
    )
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
