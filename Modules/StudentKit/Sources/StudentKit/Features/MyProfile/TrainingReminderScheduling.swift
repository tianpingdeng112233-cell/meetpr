import Foundation
import UserNotifications

enum TrainingReminderAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case denied
  case authorized
}

struct TrainingReminderRequest: Equatable, Sendable {
  let identifier: String
  let weekday: Int
  let hour: Int
  let minute: Int
  let title: String
  let body: String
}

enum TrainingReminderSchedule {
  static let identifierPrefix = "training-reminder-"

  static func requests(
    for settings: TrainingReminderSettings,
    locale: Locale = .current
  ) -> [TrainingReminderRequest] {
    guard settings.isEnabled else { return [] }
    let title = StudentStrings.localized(.trainingReminderCopy003, locale: locale)
    let body = StudentStrings.localized(.trainingReminderCopy004, locale: locale)
    return TrainingReminderWeekday.allCases
      .filter(settings.weekdays.contains)
      .map { weekday in
        TrainingReminderRequest(
          identifier: identifierPrefix + String(weekday.rawValue),
          weekday: weekday.rawValue,
          hour: settings.hour,
          minute: settings.minute,
          title: title,
          body: body
        )
      }
  }
}

protocol TrainingReminderNotificationCenter: Sendable {
  func authorizationStatus() async -> TrainingReminderAuthorizationStatus
  func requestAuthorization() async throws -> Bool
  func pendingRequestIdentifiers() async -> [String]
  func removePendingRequests(withIdentifiers identifiers: [String]) async
  func add(_ request: TrainingReminderRequest) async throws
}

actor SystemTrainingReminderNotificationCenter: TrainingReminderNotificationCenter {
  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  func authorizationStatus() async -> TrainingReminderAuthorizationStatus {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .authorized, .provisional, .ephemeral:
      return .authorized
    @unknown default:
      return .denied
    }
  }

  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound, .badge])
  }

  func pendingRequestIdentifiers() async -> [String] {
    await center.pendingNotificationRequests().map(\.identifier)
  }

  func removePendingRequests(withIdentifiers identifiers: [String]) async {
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  func add(_ request: TrainingReminderRequest) async throws {
    let content = UNMutableNotificationContent()
    content.title = request.title
    content.body = request.body
    content.sound = .default
    let components = DateComponents(
      hour: request.hour,
      minute: request.minute,
      weekday: request.weekday
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    try await center.add(
      UNNotificationRequest(
        identifier: request.identifier,
        content: content,
        trigger: trigger
      )
    )
  }
}

actor TrainingReminderScheduler {
  private let center: any TrainingReminderNotificationCenter
  private var operation: Task<Bool, Never>?

  init(center: any TrainingReminderNotificationCenter) {
    self.center = center
  }

  /// Returns `false` when any add fails; partially-added requests are rolled
  /// back so the pending set never diverges from what the caller persists.
  @discardableResult
  func replace(with settings: TrainingReminderSettings) async -> Bool {
    let previous = operation
    let center = center
    let requests = TrainingReminderSchedule.requests(for: settings)
    let operation = Task { () -> Bool in
      await previous?.value
      let identifiers = await center.pendingRequestIdentifiers()
        .filter { $0.hasPrefix(TrainingReminderSchedule.identifierPrefix) }
      await center.removePendingRequests(withIdentifiers: identifiers)
      var allAdded = true
      for request in requests {
        do {
          try await center.add(request)
        } catch {
          allAdded = false
          break
        }
      }
      if !allAdded {
        let partial = await center.pendingRequestIdentifiers()
          .filter { $0.hasPrefix(TrainingReminderSchedule.identifierPrefix) }
        await center.removePendingRequests(withIdentifiers: partial)
      }
      return allAdded
    }
    self.operation = operation
    return await operation.value
  }

  func clear() async {
    await replace(with: .defaultValue)
  }
}

enum TrainingReminderReconcileOutcome: Equatable, Sendable {
  case cleared
  case scheduled
  case disabledByPermission(denied: Bool)
  case scheduleFailed
}

/// Re-converges the pending notification set with the stored preference.
/// Runs on student-shell appearance so reminders left behind by logout paths
/// that bypass the profile screen (credential expiry, gate screens) are
/// cleaned up on the next login.
enum TrainingReminderBootstrap {
  @discardableResult
  static func reconcile(
    studentID: UUID,
    services: TrainingReminderServices
  ) async -> TrainingReminderReconcileOutcome {
    let settings = services.store.settings(for: studentID)
    guard settings.isEnabled else {
      await services.scheduler.replace(with: settings)
      return .cleared
    }
    let authorization = await services.center.authorizationStatus()
    guard authorization == .authorized else {
      await disableAndClear(settings, studentID: studentID, services: services)
      return .disabledByPermission(denied: authorization == .denied)
    }
    guard await services.scheduler.replace(with: settings) else {
      await disableAndClear(settings, studentID: studentID, services: services)
      return .scheduleFailed
    }
    return .scheduled
  }

  private static func disableAndClear(
    _ settings: TrainingReminderSettings,
    studentID: UUID,
    services: TrainingReminderServices
  ) async {
    var disabled = settings
    disabled.isEnabled = false
    services.store.setSettings(disabled, for: studentID)
    await services.scheduler.replace(with: disabled)
  }
}

struct TrainingReminderServices: Sendable {
  let store: any TrainingReminderSettingsStoring
  let center: any TrainingReminderNotificationCenter
  let scheduler: TrainingReminderScheduler

  init(
    store: any TrainingReminderSettingsStoring,
    center: any TrainingReminderNotificationCenter
  ) {
    self.store = store
    self.center = center
    self.scheduler = TrainingReminderScheduler(center: center)
  }

  /// Process-wide singleton: every call site must share one scheduler actor so
  /// clear/replace operations serialize; per-view instances would race.
  static let live = TrainingReminderServices(
    store: TrainingReminderUserDefaultsStore(),
    center: SystemTrainingReminderNotificationCenter()
  )
}
