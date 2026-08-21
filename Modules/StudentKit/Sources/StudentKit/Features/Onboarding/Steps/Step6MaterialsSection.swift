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
      uploadCard(
        icon: "doc.text", title: StudentStrings.localized(.step6MaterialsSection001),
        detail: "PNG / JPG / PDF")
      uploadCard(
        icon: "video", title: StudentStrings.localized(.step6MaterialsSection002),
        detail: StudentStrings.localized(.step6MaterialsSection003))
      OnboardingChipGrid(
        title: StudentStrings.localized(.step6MaterialsSection004),
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
        .font(.system(size: 22))
        .foregroundStyle(Color.MeetPR.textMuted)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textMuted)
        Text(detail)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      Spacer()
      Text(StudentStrings.localized(.step6MaterialsSection005))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
        .padding(.horizontal, MeetPRSpacing.sm)
        .padding(.vertical, 4)
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
