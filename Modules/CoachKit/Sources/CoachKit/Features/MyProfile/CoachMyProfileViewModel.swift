import Foundation
import Observation

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class CoachMyProfileViewModel {
  let appVersion: String
  private let logoutAction: @MainActor () async -> Void
  private(set) var isLoggingOut = false

  init(
    appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
      as? String ?? "0.1",
    logoutAction: @escaping @MainActor () async -> Void
  ) {
    self.appVersion = appVersion
    self.logoutAction = logoutAction
  }

  func logout() async {
    isLoggingOut = true
    await logoutAction()
    isLoggingOut = false
  }
}
