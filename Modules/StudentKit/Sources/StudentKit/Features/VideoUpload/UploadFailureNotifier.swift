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
    content.title = "训练视频上传失败"
    content.body = "有 \(count) 条训练视频没传成功，打开看看"
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
