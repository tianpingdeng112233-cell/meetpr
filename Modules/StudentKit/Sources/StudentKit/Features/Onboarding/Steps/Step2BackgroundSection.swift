import CoreModels
import DesignSystem
import SwiftUI

/// Step 2 训练背景: training years notch slider, squat stance, deadlift
/// style, optional bench grip. Stance art is V0.1.x — plain text cards.
@available(iOS 17.0, macOS 14.0, *)
struct Step2BackgroundSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      trainingYearsSlider
      OnboardingChoiceCards(
        title: "深蹲杠位",
        options: SquatStance.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.squatStance,
        isHighlighted: highlighted.contains("squat_stance")
      )
      OnboardingChoiceCards(
        title: "硬拉姿势",
        options: DeadliftStance.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.deadliftStyle,
        isHighlighted: highlighted.contains("deadlift_style")
      )
      benchGripPicker
    }
    .onAppear {
      // Slider anchor "<1 年" is visible from the start; the default counts
      // as the selection (notch 0 = <1 year, D8).
      if draft.trainingYears == nil {
        draft.trainingYears = 0
      }
    }
  }

  private var trainingYearsSlider: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: "训练年限", isHighlighted: highlighted.contains("training_years"))
      Slider(value: yearsBinding, in: 0...10, step: 1)
        .tint(Color.MeetPR.gold500)
      HStack {
        Text("<1 年")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
        Spacer()
        Text(OnboardingLabels.trainingYearsLabel(draft.trainingYears ?? 0))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        Text("10+ 年")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }

  private var yearsBinding: Binding<Double> {
    Binding(
      get: { Double(draft.trainingYears ?? 0) },
      set: { draft.trainingYears = Int($0.rounded()) }
    )
  }

  private var benchGripPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingChoiceCards(
        title: "卧推握距(选填)",
        options: BenchGrip.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.benchGrip
      )
      if draft.benchGrip != nil {
        Button("跳过此项") {
          draft.benchGrip = nil
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }
}
