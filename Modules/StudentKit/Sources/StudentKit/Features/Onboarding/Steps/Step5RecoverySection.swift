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
        title: "学习/工作强度",
        labels: OnboardingLabels.dailyLifeIntensityLabels,
        notch: $draft.dailyLifeIntensity,
        isHighlighted: highlighted.contains("daily_life_intensity"),
        footnote: "按身体消耗选择 — 久坐 ≠ 低消耗(如久坐但通勤负重,选中等)"
      )
      OnboardingScalePicker(
        title: "生活压力",
        labels: OnboardingLabels.lifeStressLabels,
        notch: $draft.lifeStress,
        isHighlighted: highlighted.contains("life_stress")
      )
      OnboardingScalePicker(
        title: "练后恢复时长",
        labels: OnboardingLabels.recoverySpeedLabels,
        notch: $draft.recoverySpeed,
        isHighlighted: highlighted.contains("recovery_speed"),
        footnote: "回想大强度练腿或爬山后,酸痛疲惫多久消退到能再练 — 拿不准就选 3"
      )
      OnboardingScalePicker(
        title: "睡眠时长",
        labels: OnboardingLabels.sleepHoursLabels,
        notch: $draft.sleepHours,
        isHighlighted: highlighted.contains("sleep_hours")
      )
    }
  }
}
