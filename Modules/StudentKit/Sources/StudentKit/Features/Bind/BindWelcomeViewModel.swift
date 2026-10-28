import Analytics
import Foundation
import Observation

@MainActor
@Observable
final class BindWelcomeViewModel {
  private(set) var canRequestPermission = false
  private(set) var isRequesting = false
  private let permission: StudentNotificationPermissionActions
  private let track: (AnalyticsEvent, [String: AnalyticsValue]) -> Void

  init(
    permission: StudentNotificationPermissionActions,
    track: @escaping (AnalyticsEvent, [String: AnalyticsValue]) -> Void = {
      Analytics.shared.track($0, props: $1)
    }
  ) {
    self.permission = permission
    self.track = track
  }

  func refreshPermission() async {
    canRequestPermission = await permission.canRequest()
  }

  func requestPermission() async {
    guard canRequestPermission, !isRequesting else { return }
    isRequesting = true
    defer { isRequesting = false }
    track(
      .notificationPermissionAction,
      ["source": .enumCase("welcome"), "stage": .enumCase("clicked")])
    if let result = await permission.request() {
      track(
        .notificationPermissionAction,
        [
          "source": .enumCase("welcome"), "stage": .enumCase("resolved"),
          "result": .enumCase(result ? "allowed" : "denied"),
        ])
    }
    await refreshPermission()
  }
}
