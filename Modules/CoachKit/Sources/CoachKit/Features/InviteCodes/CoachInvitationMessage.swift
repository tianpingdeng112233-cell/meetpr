import CoreModels
import Foundation
import Networking

/// The CN invitation text is shared by the profile card, copy, and share actions.
enum CoachInvitationMessage {
  static func text(
    code: String,
    coachName: String?,
    buildTrack: MeetPRBuildTrack = BuildConfig.buildTrack,
    baseURL: URL = BuildConfig.backendBaseURL,
    locale: Locale = .current,
    bundle: Bundle = .module
  ) -> String {
    guard buildTrack == .china else { return code }
    let name = coachName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let signature =
      name?.isEmpty == false
      ? name ?? ""
      : String(
        localized: "coach.invites.fallbackName", bundle: bundle, locale: locale)
    return String(localized: "coach.invites.message", bundle: bundle, locale: locale)
      .replacing("{0}", with: baseURL.appending(path: "i").appending(path: code).absoluteString)
      .replacing("{1}", with: InviteCodeFormat.grouped(code))
      .replacing("{2}", with: signature)
  }
}
