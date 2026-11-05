import Foundation
@preconcurrency import UserNotifications

extension UploadFailureNotifier {
  public func scheduleCompletionTimeout(
    count: Int, deadline: Date, destination: UploadFailureDestination
  ) async {
    guard count > 0 else { return }
    let content = Self.completionContent(count: count, completed: false, destination: destination)
    content.userInfo["videoCompletionTimeout"] = true
    let delay = deadline.timeIntervalSinceNow
    let trigger =
      delay > 0
      ? UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false) : nil
    await replaceAggregate(content: content, trigger: trigger)
  }

  public func notifyWorkoutCompleted(count: Int, destination: UploadFailureDestination) async {
    await replaceAggregate(
      content: Self.completionContent(
        count: count, completed: true,
        destination: destination), trigger: nil)
  }

  public func cancelCompletionTimeout(destination: UploadFailureDestination) async {
    await UploadNotificationDeliveryQueue.shared.perform { [center] in
      let pending = await center.pendingNotificationRequests()
      guard
        pending.contains(where: {
          $0.identifier == Self.notificationIdentifier
            && $0.content.userInfo["videoCompletionTimeout"] as? Bool == true
            && UploadFailureDestination(notificationUserInfo: $0.content.userInfo) == destination
        })
      else { return }
      center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
  }

  func replaceAggregate(
    content: UNMutableNotificationContent, trigger: UNNotificationTrigger?
  ) async {
    await UploadNotificationDeliveryQueue.shared.perform { [center] in
      let settings = await center.notificationSettings()
      guard settings.authorizationStatus != .denied else { return }
      center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
      center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
      try? await center.add(
        UNNotificationRequest(
          identifier: Self.notificationIdentifier,
          content: content, trigger: trigger))
    }
  }

  static func completionContent(count: Int, completed: Bool, destination: UploadFailureDestination)
    -> UNMutableNotificationContent
  {
    let content = UNMutableNotificationContent()
    content.title = "MeetPR"
    content.body =
      completed && count == 0
      ? StudentStrings.localized(.workoutCompletedNotification)
      : StudentStrings.replacing(
        completed ? .videoCompletionNotification : .videoTimeoutNotification,
        values: ["\(count)"])
    content.userInfo = destination.notificationUserInfo
    content.sound = .default
    return content
  }
}
