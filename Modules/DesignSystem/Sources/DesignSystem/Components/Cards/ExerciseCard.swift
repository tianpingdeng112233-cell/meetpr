import SwiftUI

public struct ExerciseSetRecord: Equatable, Sendable {
  public let index: Int
  public let weight: Double
  public let reps: Int
  public let rpe: Double
  public let status: SetRow.Status
  public let videoState: SetRow.VideoState

  public init(
    index: Int,
    weight: Double,
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

  let exercise: String
  let meta: String
  let note: String
  let collapsed: Bool
  let sets: [ExerciseSetRecord]
  private let onToggle: @MainActor (Bool) -> Void

  @State private var isOpen: Bool

  public init(
    exercise: String,
    meta: String,
    note: String,
    collapsed: Bool,
    sets: [ExerciseSetRecord],
    onToggle: @escaping @MainActor (Bool) -> Void = { _ in }
  ) {
    self.exercise = exercise
    self.meta = meta
    self.note = note
    self.collapsed = collapsed
    self.sets = sets
    self.onToggle = onToggle
    self._isOpen = State(initialValue: !collapsed)
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      header

      if isOpen {
        VStack(spacing: MeetPRSpacing.zero) {
          columnHeaders

          ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
            SetRow(
              index: set.index,
              weight: set.weight,
              reps: set.reps,
              rpe: set.rpe,
              status: set.status,
              videoState: set.videoState
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
        .transition(.opacity)
      }
    }
    .background(isOpen ? Color.MeetPR.surfaceCard : Color.MeetPR.bgStack)
    .clipShape(.rect(cornerRadius: ExerciseCardContract.radius))
    .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
    .containerRelativeFrame(.horizontal) { length, _ in
      isOpen ? length : length * ExerciseCardContract.collapsedWidthFraction
    }
    .animation(reduceMotion ? nil : MeetPRMotion.easeOut, value: isOpen)
    .onChange(of: collapsed) { _, newValue in
      isOpen = !newValue
    }
  }

  private var header: some View {
    Button(action: toggle) {
      HStack(spacing: MeetPRSpacing.point11) {
        RoundedRectangle(cornerRadius: MeetPRRadius.micro)
          .fill(allRecorded ? Color.MeetPR.success : Color.MeetPR.gold500)
          .frame(width: MeetPRSpacing.point3)
          .frame(
            minHeight: isOpen
              ? ExerciseCardContract.expandedBarMinimumHeight
              : ExerciseCardContract.collapsedBarMinimumHeight
          )
          .frame(maxHeight: .infinity)

        VStack(alignment: .leading, spacing: MeetPRSpacing.point3) {
          Text(exercise)
            .font(
              .MeetPR.display(
                size: isOpen
                  ? ExerciseCardContract.expandedNameSize
                  : ExerciseCardContract.collapsedNameSize
              )
            )
            .foregroundStyle(
              isOpen
                ? Color.MeetPR.textPrimary
                : Color.MeetPR.textSecondary
            )
            .lineLimit(1)

          if isOpen {
            Text(meta)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textMuted)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Text(isOpen ? progressText : summaryText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(allRecorded ? Color.MeetPR.success : Color.MeetPR.textDim)
          .lineLimit(1)

        Text("▾")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
          .rotationEffect(
            .degrees(isOpen ? 0 : ExerciseCardContract.collapsedCaretRotation)
          )
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.space3)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(exercise)，\(isOpen ? progressText : summaryText)")
    .accessibilityValue(isOpen ? "已展开" : "已收起")
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
    let prescription =
      "\(numberText(last.weight))kg×\(last.reps) @\(numberText(last.rpe))"
    return "\(completedSets.count) 组 · \(prescription)\(failure)"
  }

  private func toggle() {
    let newValue = !isOpen
    if reduceMotion {
      isOpen = newValue
    } else {
      withAnimation(MeetPRMotion.easeOut) {
        isOpen = newValue
      }
    }
    onToggle(newValue)
  }

  private static func numberText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

enum ExerciseCardContract {
  static let collapsedWidthFraction: CGFloat = 0.92
  static let radius: CGFloat = 16
  static let expandedNameSize: CGFloat = 16
  static let collapsedNameSize: CGFloat = 14
  static let expandedBarMinimumHeight: CGFloat = 26
  static let collapsedBarMinimumHeight: CGFloat = 18
  static let collapsedCaretRotation: Double = -90
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
