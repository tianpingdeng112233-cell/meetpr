import ActivityKit
import Foundation
import UserNotifications

@MainActor
final class RestTimerLiveActivityController {
  static let shared = RestTimerLiveActivityController()

  private var pendingOperation: Task<Void, Never>?
  private var timerEnd: Date?
  private var foreground = true
  private var soundEnabled = true
  private static let notificationID = "meetpr.rest-ring.finished"

  func setAlerts(sound: Bool, vibration: Bool) {
    soundEnabled = sound
    // iOS owns notification haptics; UNNotificationContent exposes no independent vibration control.
    refreshNotification()
  }

  func setForeground(_ active: Bool) {
    foreground = active
    refreshNotification()
  }

  private func refreshNotification() {
    enqueue { [weak self] in
      guard let self else { return }
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
      guard !foreground, let timerEnd, timerEnd > Date() else { return }
      let content = UNMutableNotificationContent()
      content.title = String(localized: "restRingFinished")
      content.sound = soundEnabled ? .default : nil
      content.userInfo = ["kind": "rest_timer_finished"]
      let request = UNNotificationRequest(
        identifier: Self.notificationID, content: content,
        trigger: UNTimeIntervalNotificationTrigger(
          timeInterval: max(0.1, timerEnd.timeIntervalSinceNow), repeats: false))
      try? await center.add(request)
    }
  }

  private func cancelNotification() {
    timerEnd = nil
    enqueue {
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
      center.removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }
  }

  func start(endsAt: Date, totalSeconds: Int) {
    timerEnd = endsAt
    enqueue {
      _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound,
      ])
    }
    refreshNotification()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    enqueue { [weak self] in
      guard let self else { return }
      await endEveryActivity()
      let state = RestTimerActivityAttributes.ContentState(
        endsAt: endsAt,
        totalSeconds: totalSeconds
      )
      let content = ActivityContent(
        state: state,
        staleDate: endsAt
      )
      _ = try? Activity.request(
        attributes: RestTimerActivityAttributes(),
        content: content,
        pushType: nil
      )
    }
  }

  func update(endsAt: Date, totalSeconds: Int) {
    timerEnd = endsAt
    refreshNotification()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    enqueue {
      let state = RestTimerActivityAttributes.ContentState(
        endsAt: endsAt,
        totalSeconds: totalSeconds
      )
      let content = ActivityContent(
        state: state,
        staleDate: endsAt
      )
      for activity in Activity<RestTimerActivityAttributes>.activities {
        await activity.update(content)
      }
    }
  }

  func end() {
    cancelNotification()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    enqueue { [weak self] in
      guard let self else { return }
      await endEveryActivity()
    }
  }

  func cleanUpExpiredActivities(at date: Date = Date()) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    enqueue {
      for activity in Activity<RestTimerActivityAttributes>.activities
      where activity.content.state.endsAt <= date {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  func cleanUpAllActivities() {
    cancelNotification()
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    enqueue { [weak self] in
      guard let self else { return }
      await endEveryActivity()
    }
  }

  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previousOperation = pendingOperation
    pendingOperation = Task { @MainActor in
      await previousOperation?.value
      guard !Task.isCancelled else { return }
      await operation()
    }
  }

  private func endEveryActivity() async {
    for activity in Activity<RestTimerActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }
}
