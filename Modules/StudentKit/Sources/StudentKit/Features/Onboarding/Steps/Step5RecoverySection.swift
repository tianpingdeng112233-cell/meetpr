import CoreModels
import DesignSystem
import SwiftUI

/// Step 5 恢复能力: four 1-5 notch scales (D8 — the wire carries notches).
@available(iOS 17.0, macOS 14.0, *)
struct Step5RecoverySection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      OnboardingScalePicker(
        title: StudentStrings.localized(.step5RecoverySection001),
        labels: OnboardingLabels.dailyLifeIntensityLabels,
        notch: $draft.dailyLifeIntensity,
        isHighlighted: highlighted.contains("daily_life_intensity"),
        footnote: StudentStrings.localized(.step5RecoverySection002)
      )
      OnboardingScalePicker(
        title: StudentStrings.localized(.step5RecoverySection003),
        labels: OnboardingLabels.lifeStressLabels,
        notch: $draft.lifeStress,
        isHighlighted: highlighted.contains("life_stress")
      )
      OnboardingScalePicker(
        title: StudentStrings.localized(.step5RecoverySection004),
        labels: OnboardingLabels.recoverySpeedLabels,
        notch: $draft.recoverySpeed,
        isHighlighted: highlighted.contains("recovery_speed"),
        footnote: StudentStrings.localized(.step5RecoverySection005)
      )
      OnboardingScalePicker(
        title: StudentStrings.localized(.step5RecoverySection006),
        labels: OnboardingLabels.sleepHoursLabels,
        notch: $draft.sleepHours,
        isHighlighted: highlighted.contains("sleep_hours")
      )
    }
  }
}
