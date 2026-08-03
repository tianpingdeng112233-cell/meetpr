import AppShell
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
}
