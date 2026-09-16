import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachLogoutConfirmationView: View {
  let isLoggingOut: Bool
  let onCancel: @MainActor () -> Void
  let onLogout: @MainActor () -> Void

  var body: some View {
    ZStack {
      Button(action: onCancel) {
        Color.MeetPR.textPrimary.opacity(0.6)
          .ignoresSafeArea()
      }
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        Text(CoachMyProfileStrings.logoutTitle)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size21))
          .foregroundStyle(Color.MeetPR.textPrimary)

        Text(CoachMyProfileStrings.logoutMessage)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineSpacing(MeetPRSpacing.space2)
          .padding(.top, MeetPRSpacing.point10)

        HStack(spacing: MeetPRSpacing.point10) {
          Button(CoachMyProfileStrings.cancel, action: onCancel)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeetPRSpacing.point14)
            .overlay {
              Capsule()
                .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
            }
            .accessibilityIdentifier("coach.profile.logout.cancel")

          Button(
            isLoggingOut
              ? CoachMyProfileStrings.loggingOut
              : CoachMyProfileStrings.confirmLogout,
            action: onLogout
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.danger)
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.point14)
          .background(Color.MeetPR.danger.opacity(0.1), in: .capsule)
          .overlay {
            Capsule()
              .stroke(Color.MeetPR.danger.opacity(0.4), lineWidth: MeetPRSpacing.point1)
          }
          .disabled(isLoggingOut)
          .accessibilityIdentifier("coach.profile.logout.confirm")
        }
        .buttonStyle(PressScaleButtonStyle(isDisabled: isLoggingOut))
        .padding(.top, MeetPRSpacing.space5)
      }
      .padding(MeetPRSpacing.point22)
      .frame(maxWidth: .infinity, alignment: .leading)
      .meetPRCardSurface(.modal)
      .padding(.horizontal, MeetPRSpacing.point28)
    }
  }
}
