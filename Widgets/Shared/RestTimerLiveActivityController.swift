import ActivityKit
import Foundation

@MainActor
final class RestTimerLiveActivityController {
  static let shared = RestTimerLiveActivityController()

  private var pendingOperation: Task<Void, Never>?

  func start(endsAt: Date, totalSeconds: Int) {
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
