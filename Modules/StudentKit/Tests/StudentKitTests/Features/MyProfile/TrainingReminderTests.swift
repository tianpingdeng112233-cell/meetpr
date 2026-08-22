import Foundation
import Testing

@testable import StudentKit

@Suite("Training reminders")
struct TrainingReminderTests {
  private let chinese = Locale(identifier: "zh-Hans")
  private let english = Locale(identifier: "en")

  @Test("Default settings are off with Monday Wednesday Friday at 20:00")
  func defaultSettings() {
    let settings = TrainingReminderSettings.defaultValue

    #expect(!settings.isEnabled)
    #expect(settings.weekdays == [.monday, .wednesday, .friday])
    #expect(settings.hour == 20)
    #expect(settings.minute == 0)
  }

  @Test("Multiple weekdays produce one deterministic request each")
  func multipleWeekdaySchedule() {
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [.monday, .wednesday, .friday],
      hour: 20,
      minute: 5
    )

    let requests = TrainingReminderSchedule.requests(for: settings, locale: chinese)

    #expect(
      requests.map(\.identifier) == [
        "training-reminder-2", "training-reminder-4", "training-reminder-6",
      ])
    #expect(requests.map(\.weekday) == [2, 4, 6])
    #expect(requests.allSatisfy { $0.hour == 20 && $0.minute == 5 })
    #expect(requests.allSatisfy { $0.title == "训练日到了" })
    #expect(requests.allSatisfy { $0.body == "该练了，今天的安排在等你" })
  }

  @Test("A single Sunday uses Calendar weekday one")
  func singleWeekdaySchedule() throws {
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [.sunday],
      hour: 9,
      minute: 30
    )

    let request = try #require(
      TrainingReminderSchedule.requests(for: settings, locale: english).first
    )

    #expect(request.identifier == "training-reminder-1")
    #expect(request.weekday == 1)
    #expect(request.hour == 9)
    #expect(request.minute == 30)
    #expect(request.title == "Training day is here")
    #expect(request.body == "Time to train. Today's plan is waiting for you.")
  }

  @Test("An enabled reminder with no weekdays produces no requests")
  func emptyWeekdaySchedule() {
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [],
      hour: 20,
      minute: 0
    )

    #expect(TrainingReminderSchedule.requests(for: settings).isEmpty)
  }

  @Test("A disabled reminder produces no requests")
  func disabledSchedule() {
    #expect(TrainingReminderSchedule.requests(for: .defaultValue).isEmpty)
  }

  @Test("Changing settings removes only reminder requests before rescheduling")
  func settingsChangeReplacesSchedule() async {
    let center = FakeTrainingReminderNotificationCenter(
      pendingIdentifiers: ["training-reminder-2", "training-reminder-6", "chat-message-1"]
    )
    let scheduler = TrainingReminderScheduler(center: center)
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [.tuesday],
      hour: 7,
      minute: 45
    )

    await scheduler.replace(with: settings)

    let snapshot = await center.snapshot()
    #expect(snapshot.pendingIdentifiers == ["chat-message-1", "training-reminder-3"])
    #expect(
      snapshot.operations == [
        "pending",
        "remove:training-reminder-2,training-reminder-6",
        "add:training-reminder-3",
      ])
    #expect(snapshot.requests["training-reminder-3"]?.hour == 7)
    #expect(snapshot.requests["training-reminder-3"]?.minute == 45)
  }

  @Test("Turning reminders off clears the prefix and leaves unrelated requests")
  func disablingClearsSchedule() async {
    let center = FakeTrainingReminderNotificationCenter(
      pendingIdentifiers: ["training-reminder-4", "upload-finished-1"]
    )
    let scheduler = TrainingReminderScheduler(center: center)

    await scheduler.replace(with: .defaultValue)

    let snapshot = await center.snapshot()
    #expect(snapshot.pendingIdentifiers == ["upload-finished-1"])
    #expect(snapshot.requests.isEmpty)
  }

  @Test("Logout cleanup clears only training reminder requests")
  func logoutCleanup() async {
    let center = FakeTrainingReminderNotificationCenter(
      pendingIdentifiers: ["training-reminder-2", "training-reminder-4", "remote-push-1"]
    )
    let scheduler = TrainingReminderScheduler(center: center)

    await scheduler.clear()

    let snapshot = await center.snapshot()
    #expect(snapshot.pendingIdentifiers == ["remote-push-1"])
  }

  @Test("Summary is localized in Chinese and English")
  func localizedSummary() {
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [.monday, .wednesday, .friday],
      hour: 8,
      minute: 5
    )

    #expect(TrainingReminderCopy.summary(for: settings, locale: chinese) == "周一·三·五 08:05")
    #expect(
      TrainingReminderCopy.summary(for: settings, locale: english) == "Mon · Wed · Fri 08:05"
    )
    #expect(
      TrainingReminderCopy.summary(for: .defaultValue, locale: chinese) == "关"
    )
  }

  @Test("Denied authorization rolls the toggle back and is not requested again")
  @MainActor
  func deniedAuthorization() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      authorizationStatus: .notDetermined,
      authorizationResult: false
    )
    let fixture = try makeViewModel(center: center)

    await fixture.viewModel.setEnabled(true)
    await fixture.viewModel.setEnabled(true)

    let snapshot = await center.snapshot()
    #expect(!fixture.viewModel.settings.isEnabled)
    #expect(fixture.viewModel.showsPermissionDenied)
    #expect(snapshot.authorizationRequestCount == 1)
    #expect(snapshot.pendingIdentifiers.isEmpty)
  }

  @Test("Allowed authorization enables and schedules the defaults")
  @MainActor
  func allowedAuthorization() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      authorizationStatus: .notDetermined,
      authorizationResult: true
    )
    let fixture = try makeViewModel(center: center)

    await fixture.viewModel.setEnabled(true)

    let snapshot = await center.snapshot()
    #expect(fixture.viewModel.settings.isEnabled)
    #expect(!fixture.viewModel.showsPermissionDenied)
    #expect(snapshot.authorizationRequestCount == 1)
    #expect(
      snapshot.pendingIdentifiers == [
        "training-reminder-2", "training-reminder-4", "training-reminder-6",
      ])
  }

  @MainActor
  private func makeViewModel(
    center: FakeTrainingReminderNotificationCenter
  ) throws -> (viewModel: TrainingReminderSettingsViewModel, defaults: UserDefaults) {
    let suiteName = "TrainingReminderTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let services = TrainingReminderServices(
      store: TrainingReminderUserDefaultsStore(defaults: defaults),
      center: center
    )
    return (
      TrainingReminderSettingsViewModel(
        studentID: UUID(),
        services: services
      ),
      defaults
    )
  }
}

actor FakeTrainingReminderNotificationCenter: TrainingReminderNotificationCenter {
  struct Snapshot: Sendable {
    let authorizationRequestCount: Int
    let pendingIdentifiers: [String]
    let requests: [String: TrainingReminderRequest]
    let operations: [String]
  }

  struct AddFailure: Error {}

  private var status: TrainingReminderAuthorizationStatus
  private let authorizationResult: Bool
  private let addFailingIdentifiers: Set<String>
  private var authorizationRequestCount = 0
  private var pendingIdentifiers: Set<String>
  private var requests: [String: TrainingReminderRequest] = [:]
  private var operations: [String] = []

  init(
    authorizationStatus: TrainingReminderAuthorizationStatus = .authorized,
    authorizationResult: Bool = true,
    pendingIdentifiers: Set<String> = [],
    addFailingIdentifiers: Set<String> = []
  ) {
    self.status = authorizationStatus
    self.authorizationResult = authorizationResult
    self.pendingIdentifiers = pendingIdentifiers
    self.addFailingIdentifiers = addFailingIdentifiers
  }

  func setAuthorizationStatus(_ status: TrainingReminderAuthorizationStatus) {
    self.status = status
  }

  func authorizationStatus() -> TrainingReminderAuthorizationStatus {
    status
  }

  func requestAuthorization() throws -> Bool {
    authorizationRequestCount += 1
    status = authorizationResult ? .authorized : .denied
    return authorizationResult
  }

  func pendingRequestIdentifiers() -> [String] {
    operations.append("pending")
    return pendingIdentifiers.sorted()
  }

  func removePendingRequests(withIdentifiers identifiers: [String]) {
    let sortedIdentifiers = identifiers.sorted()
    operations.append("remove:\(sortedIdentifiers.joined(separator: ","))")
    pendingIdentifiers.subtract(sortedIdentifiers)
    for identifier in sortedIdentifiers {
      requests.removeValue(forKey: identifier)
    }
  }

  func add(_ request: TrainingReminderRequest) throws {
    if addFailingIdentifiers.contains(request.identifier) {
      operations.append("addFailed:\(request.identifier)")
      throw AddFailure()
    }
    operations.append("add:\(request.identifier)")
    pendingIdentifiers.insert(request.identifier)
    requests[request.identifier] = request
  }

  func snapshot() -> Snapshot {
    Snapshot(
      authorizationRequestCount: authorizationRequestCount,
      pendingIdentifiers: pendingIdentifiers.sorted(),
      requests: requests,
      operations: operations
    )
  }
}
