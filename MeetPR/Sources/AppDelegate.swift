import AppShell
import StudentKit
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
  static weak var pushRegistrar: PushRegistrar?

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Self.pushRegistrar?.receivedDeviceToken(DeviceTokenHex.string(from: deviceToken))
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    Self.pushRegistrar?.remoteRegistrationFailed(error)
  }

  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    BackgroundUploadCompletionRegistry.shared.store(
      identifier: identifier,
      completion: completionHandler
    )
    BackgroundUploadSessionLifecycle.shared.reconnect(identifier: identifier)
  }
}
