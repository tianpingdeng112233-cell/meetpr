import Foundation
import Observation

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class CoachMyProfileViewModel {
  let appVersion: String
  let displayName: String
  private let logoutAction: @MainActor () async -> Void
  private(set) var isLoggingOut = false

  init(
    appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
      as? String ?? "0.1",
    displayName: String? = nil,
    logoutAction: @escaping @MainActor () async -> Void
  ) {
    self.appVersion = appVersion
    let normalizedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.displayName =
      normalizedName?.isEmpty == false
      ? normalizedName ?? CoachMyProfileStrings.fallbackName
      : CoachMyProfileStrings.fallbackName
    self.logoutAction = logoutAction
  }

  func logout() async {
    isLoggingOut = true
    await logoutAction()
    isLoggingOut = false
  }
}
