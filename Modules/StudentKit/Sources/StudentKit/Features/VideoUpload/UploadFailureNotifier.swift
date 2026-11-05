import Foundation
@preconcurrency import UserNotifications

public protocol UploadFailureNotifying: Sendable {
  func requestAuthorization() async
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async
}

public struct UploadFailureNotifier: UploadFailureNotifying {
  public static let notificationIdentifier = "video-upload-terminal-failures"

  private let center: UNUserNotificationCenter

  public init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  public func requestAuthorization() async {
    let settings = await center.notificationSettings()
    guard Self.shouldRequestAuthorization(status: settings.authorizationStatus) else { return }
    _ = try? await center.requestAuthorization(options: Self.authorizationOptions)
  }

  public func notifyTerminalFailures(
    count: Int,
    destination: UploadFailureDestination
  ) async {
    guard count > 0 else { return }
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus != .denied else { return }

    center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
    center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    let request = UNNotificationRequest(
      identifier: Self.notificationIdentifier,
      content: Self.content(count: count, destination: destination),
      trigger: nil)
    try? await center.add(request)
  }

  static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .badge]

  static func shouldRequestAuthorization(status: UNAuthorizationStatus) -> Bool {
    status == .notDetermined || status == .provisional
  }

  static func content(count: Int, destination: UploadFailureDestination)
    -> UNMutableNotificationContent
  {
    let content = UNMutableNotificationContent()
    content.title = StudentStrings.localized(.uploadFailureNotifier001)
    content.body = StudentStrings.replacing(.uploadFailureNotifier002, values: ["\(count)"])
    content.userInfo = destination.notificationUserInfo
    content.sound = .default
    return content
  }
}

struct NoopUploadFailureNotifier: UploadFailureNotifying {
  func requestAuthorization() async {}
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async {}
}
