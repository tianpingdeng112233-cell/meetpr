import DesignSystem
import Networking
import SwiftUI

/// Only the Demo app overrides this value; production follows BuildConfig.
private struct CoachInvitationBuildTrackKey: EnvironmentKey {
  static var defaultValue: MeetPRBuildTrack { BuildConfig.buildTrack }
}

extension EnvironmentValues {
  public var coachInvitationBuildTrack: MeetPRBuildTrack {
    get { self[CoachInvitationBuildTrackKey.self] }
    set { self[CoachInvitationBuildTrackKey.self] = newValue }
  }
}

struct CoachInvitationActions: View {
  let code: String
  let coachName: String?
  let isCopied: Bool
  let onCopy: @MainActor () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.sm) {
      CoachInvitationShareLink(code: code, coachName: coachName)
      SecondaryButton(
        isCopied
          ? InviteCodeStrings.copied : CoachLocalization.localized("coach.invites.copyMessage"),
        isFullWidth: true, action: onCopy
      )
      .accessibilityIdentifier("coach.invites.copyMessage")
    }
  }
}

struct CoachInvitationShareLink: View {
  let code: String
  let coachName: String?

  @State private var isSharing = false

  var body: some View {
    #if os(iOS)
      Button {
        isSharing = true
      } label: {
        PrimaryButtonLabel(
          CoachLocalization.localized("coach.invites.shareToStudent"),
          systemImage: "square.and.arrow.up", isFullWidth: true)
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityIdentifier("coach.invites.share")
      .sheet(isPresented: $isSharing) {
        CoachInvitationActivitySheet(code: code, coachName: coachName) {
          isSharing = false
        }
      }
    #else
      let title = CoachInvitationMessage.shareTitle(coachName: coachName)
      ShareLink(
        item: CoachInvitationMessage.inviteURL(code: code),
        subject: Text(title),
        message: Text(
          CoachInvitationMessage.text(code: code, coachName: coachName, buildTrack: .china)),
        preview: SharePreview(title, image: Image("InviteShareIcon", bundle: .module))
      ) {
        PrimaryButtonLabel(
          CoachLocalization.localized("coach.invites.shareToStudent"),
          systemImage: "square.and.arrow.up", isFullWidth: true)
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityIdentifier("coach.invites.share")
    #endif
  }
}
