import CoreModels
import DesignSystem
import SwiftUI

/// Step 6 训练资料: upload cards ship DISABLED (spec 032 §8 degraded form —
/// the spec-027 pipeline integrates in a follow-up PR; `uploadsEnabled` is
/// the pre-wired seam) + the ≤3 muscle-group chips.
@available(iOS 17.0, macOS 14.0, *)
struct Step6MaterialsSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []
  /// 027 integration seam — constant false until the upload pipeline lands.
  var uploadsEnabled = false

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      uploadCard(icon: "doc.text", title: "上传训练计划", detail: "PNG / JPG / PDF")
      uploadCard(icon: "video", title: "三大项动作视频", detail: "深蹲 / 卧推 / 硬拉 各 ≤3 个")
      OnboardingChipGrid(
        title: "想增强的肌群(最多 3 个,可选)",
        options: OnboardingProfile.strengthenMuscleGroups.map {
          ($0, OnboardingLabels.strengthenLabel($0))
        },
        selection: $draft.muscleGroupsToStrengthen,
        maxSelection: 3
      )
    }
  }

  private func uploadCard(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: MeetPRSpacing.md) {
      Image(systemName: icon)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size22))
        .foregroundStyle(Color.MeetPR.textTertiary)
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(title)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textSecondary)
        Text(detail)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      Spacer()
      Text("即将开放")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.textTertiary)
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, MeetPRSpacing.space1)
        .background(Color.MeetPR.surfaceElevated)
        .clipShape(Capsule())
    }
    .padding(MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    .opacity(uploadsEnabled ? 1 : 0.55)
  }
}
