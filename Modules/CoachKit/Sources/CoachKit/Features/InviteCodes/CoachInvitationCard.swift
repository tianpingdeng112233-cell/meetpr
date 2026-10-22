import CoreModels
import DesignSystem
import SwiftUI

struct CoachInvitationCard: View {
  let code: InviteCode
  let coachName: String?
  let isCopied: Bool
  let onManage: @MainActor () -> Void
  let onCopy: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      HStack {
        Text(CoachMyProfileStrings.permanentInvite)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
        Spacer()
        Button(action: onManage) {
          HStack(spacing: MeetPRSpacing.xs) {
            Text(CoachLocalization.localized("coach.invites.manage"))
            Image(systemName: "chevron.right")
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("coach.profile.manageInvites")
      }
      Text(code.code)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size26, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      Text(CoachMyProfileStrings.inviteUsage(code.usedCount))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
      CoachInvitationActions(
        code: code.code, coachName: coachName, isCopied: isCopied, onCopy: onCopy)
    }
    .padding(MeetPRSpacing.space4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .meetPRCardSurface(.card)
    .accessibilityIdentifier("coach.profile.inviteCard")
  }
}
