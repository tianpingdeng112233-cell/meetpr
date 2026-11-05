import Foundation
@preconcurrency import UserNotifications

public protocol UploadFailureNotifying: Sendable {
  func requestAuthorization() async
  func scheduleCompletionTimeout(count: Int, deadline: Date, destination: UploadFailureDestination)
    async
  func notifyWorkoutCompleted(count: Int, destination: UploadFailureDestination) async
  func cancelCompletionTimeout(destination: UploadFailureDestination) async
  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async
}

public struct UploadFailureNotifier: UploadFailureNotifying {
  public static let notificationIdentifier = "video-upload-terminal-failures"

  let center: UNUserNotificationCenter

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
    await replaceAggregate(
      content: Self.content(count: count, destination: destination), trigger: nil)
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

extension UploadFailureNotifying {
  public func cancelCompletionTimeout(destination: UploadFailureDestination) async {}
  public func scheduleCompletionTimeout(
    count: Int, deadline: Date, destination: UploadFailureDestination
  ) async {}
  public func notifyWorkoutCompleted(count: Int, destination: UploadFailureDestination) async {}
}
