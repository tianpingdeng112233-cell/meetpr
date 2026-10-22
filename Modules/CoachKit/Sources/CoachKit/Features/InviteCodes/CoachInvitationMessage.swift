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
    return String(localized: "coach.invites.message", bundle: bundle, locale: locale)
      .replacing("{0}", with: inviteURL(code: code, baseURL: baseURL).absoluteString)
      .replacing("{1}", with: InviteCodeFormat.grouped(code))
      .replacing("{2}", with: signature(coachName: coachName, locale: locale, bundle: bundle))
  }

  static func inviteURL(code: String, baseURL: URL = BuildConfig.backendBaseURL) -> URL {
    baseURL.appending(path: "i").appending(path: code)
  }

  static func shareTitle(
    coachName: String?, locale: Locale = .current, bundle: Bundle = .module
  ) -> String {
    let name = coachName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !name.isEmpty else {
      return String(localized: "coach.invites.shareTitleFallback", bundle: bundle, locale: locale)
    }
    return String(localized: "coach.invites.shareTitle", bundle: bundle, locale: locale)
      .replacing("{0}", with: name)
  }

  private static func signature(coachName: String?, locale: Locale, bundle: Bundle) -> String {
    let name = coachName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return name.isEmpty
      ? String(localized: "coach.invites.fallbackName", bundle: bundle, locale: locale)
      : name
  }
}
