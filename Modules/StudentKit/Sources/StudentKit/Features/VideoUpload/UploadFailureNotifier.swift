import Foundation
@preconcurrency import UserNotifications

public protocol UploadFailureNotifying: Sendable {
  func requestProvisionalAuthorization() async
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async
}

public struct UploadFailureNotifier: UploadFailureNotifying {
  public static let notificationIdentifier = "video-upload-terminal-failures"

  private let center: UNUserNotificationCenter

  public init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  public func requestProvisionalAuthorization() async {
    _ = try? await center.requestAuthorization(options: [.provisional])
  }

  public func notifyTerminalFailures(
    count: Int,
    destination: UploadFailureDestination
  ) async {
    guard count > 0 else { return }
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus != .denied else { return }

    let content = UNMutableNotificationContent()
    content.title = StudentStrings.localized(.uploadFailureNotifier001)
    content.body = StudentStrings.replacing(.uploadFailureNotifier002, values: ["\(count)"])
    content.userInfo = destination.notificationUserInfo
    let request = UNNotificationRequest(
      identifier: Self.notificationIdentifier,
      content: content,
      trigger: nil
    )
    try? await center.add(request)
  }
}

struct NoopUploadFailureNotifier: UploadFailureNotifying {
  func requestProvisionalAuthorization() async {}
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async {}
}
