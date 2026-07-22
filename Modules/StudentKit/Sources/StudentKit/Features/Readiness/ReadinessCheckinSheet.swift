import CoreModels
import DesignSystem
import SwiftUI

/// Two-step pre-workout check-in (spec 030 §C5). Step 1: four 5-dot scales
/// (all must be picked). Step 2: sore muscle chips with a tap-to-cycle
/// severity (轻微→中等→明显酸痛→严重酸痛→完全无酸痛); none selected is legal.
@available(iOS 17.0, macOS 14.0, *)
struct ReadinessCheckinSheet: View {
  let studentID: UUID
  let viewModel: ReadinessCheckinViewModel
  let onClose: () -> Void

  @State private var draft: ReadinessDraft
  @State private var step = 1
  @State private var submitting = false

  init(
    studentID: UUID,
    viewModel: ReadinessCheckinViewModel,
    prefill: ReadinessCheckin? = nil,
    onClose: @escaping () -> Void
  ) {
    self.studentID = studentID
    self.viewModel = viewModel
    self.onClose = onClose
    self._draft = State(initialValue: prefill.map(ReadinessDraft.init(from:)) ?? ReadinessDraft())
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          if step == 1 {
            stepOne
          } else {
            stepTwo
          }
        }
        .padding(MeetPRSpacing.md)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle("今日状态 \(step)/2")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("跳过") {
            viewModel.skip(studentId: studentID)
            onClose()
          }
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
      .safeAreaInset(edge: .bottom) {
        footer
          .padding(MeetPRSpacing.md)
          .background(Color.MeetPR.bg)
      }
    }
    .interactiveDismissDisabled()
  }

  // MARK: - Step 1

  private var stepOne: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      scaleRow(
        scale: .sleepQuality,
        value: $draft.sleepQuality
      )
      scaleRow(
        scale: .energy,
        value: $draft.energy
      )
      scaleRow(
        scale: .stress,
        value: $draft.stress
      )
      scaleRow(
        scale: .mood,
        value: $draft.mood
      )
    }
  }

  private func scaleRow(
    scale: ReadinessScale,
    value: Binding<Int?>
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(scale.title)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      HStack(spacing: MeetPRSpacing.sm) {
        ForEach(1...5, id: \.self) { level in
          Button {
            value.wrappedValue = level
          } label: {
            Circle()
              .fill(
                (value.wrappedValue ?? 0) >= level
                  ? Color.MeetPR.fgPrimary : Color.MeetPR.surface3
              )
              .frame(width: 30, height: 30)
              .overlay(
                Circle().strokeBorder(
                  value.wrappedValue == level ? Color.MeetPR.bg : .clear, lineWidth: 2)
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(scale.title)，\(scale.label(for: level) ?? "\(level) 分")")
        }
      }
      // Dots and the picked-tier copy stay leading-aligned with the question.
      // They were centred while the row still had the 56pt anchor labels on
      // both ends; without those, centring leaves a dead gutter on the left
      // and reads as misaligned against the title.
      Text(value.wrappedValue.flatMap(scale.label(for:)) ?? "请选择一档")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(
          value.wrappedValue == nil ? Color.MeetPR.fgTertiary : Color.MeetPR.fgPrimary
        )
    }
    // The row must still claim the full width — otherwise the step collapses
    // to the widest child (the 5 dots) and the sheet renders as a narrow
    // column. Width comes from the frame, alignment keeps the content leading.
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Step 2

  private var stepTwo: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Text("今天哪些肌群酸痛？")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text("点按肌群：轻微 → 中等 → 明显酸痛 → 严重酸痛 → 完全无酸痛。不点就是完全无酸痛。")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)

      FlowChips(
        groups: ReadinessCheckin.allowedMuscleGroups,
        severity: { draft.fatigue[$0] },
        onTap: { group in
          draft.fatigue[group] = ReadinessMuscleSoreness.nextSeverity(
            after: draft.fatigue[group]
          )
        }
      )

      if let error = viewModel.submitError {
        Label(error, systemImage: "exclamationmark.triangle")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    HStack {
      if step == 2 {
        Button("上一步") { step = 1 }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.fgSecondary)
      }
      Spacer()
      if step == 1 {
        Button("下一步") { step = 2 }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .disabled(!draft.stepOneComplete)
      } else {
        Button(submitting ? "提交中…" : "完成") {
          submitting = true
          Task {
            let success = await viewModel.submit(draft, studentId: studentID)
            submitting = false
            if success { onClose() }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.brandRed)
        .disabled(submitting)
      }
    }
  }
}

/// Wrapping chip grid for the 8 whitelisted groups; severity uses the exact
/// student-facing soreness copy instead of an unlabeled number.
@available(iOS 17.0, macOS 14.0, *)
private struct FlowChips: View {
  let groups: [MuscleGroup]
  let severity: (MuscleGroup) -> Int?
  let onTap: (MuscleGroup) -> Void

  private let columns = [GridItem(.adaptive(minimum: 92), spacing: MeetPRSpacing.xs)]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: MeetPRSpacing.xs) {
      ForEach(groups, id: \.self) { group in
        let level = severity(group)
        Button {
          onTap(group)
        } label: {
          VStack(spacing: 2) {
            Text(Self.displayName(group))
              .font(Font.MeetPR.footnote)
            Text(ReadinessMuscleSoreness.label(for: level))
              .font(Font.MeetPR.caption)
          }
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .background(level == nil ? Color.MeetPR.surface2 : Color.MeetPR.surface3)
          .foregroundStyle(level == nil ? Color.MeetPR.fgSecondary : Color.MeetPR.fgPrimary)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
          .overlay(
            RoundedRectangle(cornerRadius: MeetPRRadius.md)
              .strokeBorder(
                level == nil ? Color.MeetPR.border : Color.MeetPR.fgPrimary, lineWidth: 1)
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          "\(Self.displayName(group))，\(ReadinessMuscleSoreness.label(for: level))"
        )
      }
    }
  }

  /// Chinese display for the 8 whitelisted groups (full catalog mapping lives
  /// coach-side; StudentKit only ever shows these eight).
  private static func displayName(_ group: MuscleGroup) -> String {
    switch group {
    case .quad: "股四"
    case .hamstring: "腘绳"
    case .glute: "臀"
    case .back: "背"
    case .chest: "胸"
    case .shoulder: "肩"
    case .triceps: "肱三头"
    case .core: "核心·下背"
    default: group.rawValue
    }
  }
}
