import Foundation
import Testing

@testable import StudentKit

/// Failure-recovery and cross-account coverage for training reminders:
/// add-failure rollback, shell reconcile, foreground permission refresh,
/// and per-student preference isolation.
@Suite("Training reminder recovery")
struct TrainingReminderRecoveryTests {
  private struct ServicesHarness {
    let services: TrainingReminderServices
    let store: TrainingReminderUserDefaultsStore
  }

  private struct ViewModelFixture {
    let viewModel: TrainingReminderSettingsViewModel
    let store: TrainingReminderUserDefaultsStore
    let studentID: UUID
  }

  @Test("A failed add rolls the partial schedule back to empty")
  func addFailureRollsBack() async {
    let center = FakeTrainingReminderNotificationCenter(
      pendingIdentifiers: ["remote-push-1"],
      addFailingIdentifiers: ["training-reminder-4"]
    )
    let scheduler = TrainingReminderScheduler(center: center)
    let settings = TrainingReminderSettings(
      isEnabled: true,
      weekdays: [.monday, .wednesday],
      hour: 20,
      minute: 0
    )

    let succeeded = await scheduler.replace(with: settings)

    let snapshot = await center.snapshot()
    #expect(!succeeded)
    #expect(snapshot.pendingIdentifiers == ["remote-push-1"])
  }

  @Test("Schedule failure falls the toggle and the stored preference back to off")
  @MainActor
  func scheduleFailureFallsBack() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      addFailingIdentifiers: ["training-reminder-6"]
    )
    let fixture = try makeViewModel(center: center)

    await fixture.viewModel.setEnabled(true)

    let snapshot = await center.snapshot()
    #expect(!fixture.viewModel.settings.isEnabled)
    #expect(fixture.viewModel.showsScheduleFailure)
    #expect(!fixture.store.settings(for: fixture.studentID).isEnabled)
    #expect(!snapshot.pendingIdentifiers.contains { $0.hasPrefix("training-reminder-") })
  }

  @Test("Reconcile clears stale reminders left by a bypassed logout")
  func reconcileClearsWhenDisabled() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      pendingIdentifiers: ["training-reminder-2", "remote-push-1"]
    )
    let harness = try makeServices(center: center)

    let outcome = await TrainingReminderBootstrap.reconcile(
      studentID: UUID(),
      services: harness.services
    )

    let snapshot = await center.snapshot()
    #expect(outcome == .cleared)
    #expect(snapshot.pendingIdentifiers == ["remote-push-1"])
  }

  @Test("Reconcile reschedules an enabled authorized preference")
  func reconcileReschedules() async throws {
    let center = FakeTrainingReminderNotificationCenter()
    let harness = try makeServices(center: center)
    let studentID = UUID()
    var settings = TrainingReminderSettings.defaultValue
    settings.isEnabled = true
    settings.weekdays = [.tuesday]
    harness.store.setSettings(settings, for: studentID)

    let outcome = await TrainingReminderBootstrap.reconcile(
      studentID: studentID,
      services: harness.services
    )

    let snapshot = await center.snapshot()
    #expect(outcome == .scheduled)
    #expect(snapshot.pendingIdentifiers == ["training-reminder-3"])
  }

  @Test("Reconcile disables the stored preference when permission is gone")
  func reconcileDisablesWithoutPermission() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      authorizationStatus: .denied,
      pendingIdentifiers: ["training-reminder-2"]
    )
    let harness = try makeServices(center: center)
    let studentID = UUID()
    var settings = TrainingReminderSettings.defaultValue
    settings.isEnabled = true
    harness.store.setSettings(settings, for: studentID)

    let outcome = await TrainingReminderBootstrap.reconcile(
      studentID: studentID,
      services: harness.services
    )

    let snapshot = await center.snapshot()
    #expect(outcome == .disabledByPermission(denied: true))
    #expect(!harness.store.settings(for: studentID).isEnabled)
    #expect(snapshot.pendingIdentifiers.isEmpty)
  }

  @Test("Foreground refresh clears the denied banner once authorized")
  @MainActor
  func refreshAuthorizationClearsBanner() async throws {
    let center = FakeTrainingReminderNotificationCenter(
      authorizationStatus: .notDetermined,
      authorizationResult: false
    )
    let fixture = try makeViewModel(center: center)
    await fixture.viewModel.setEnabled(true)
    #expect(fixture.viewModel.showsPermissionDenied)

    await center.setAuthorizationStatus(.authorized)
    await fixture.viewModel.refreshAuthorization()

    #expect(!fixture.viewModel.showsPermissionDenied)
  }

  @Test("Foreground refresh rolls back when permission was revoked in Settings")
  @MainActor
  func refreshAuthorizationRollsBackRevocation() async throws {
    let center = FakeTrainingReminderNotificationCenter()
    let fixture = try makeViewModel(center: center)
    await fixture.viewModel.setEnabled(true)
    #expect(fixture.viewModel.settings.isEnabled)

    await center.setAuthorizationStatus(.denied)
    await fixture.viewModel.refreshAuthorization()

    let snapshot = await center.snapshot()
    #expect(!fixture.viewModel.settings.isEnabled)
    #expect(fixture.viewModel.showsPermissionDenied)
    #expect(!snapshot.pendingIdentifiers.contains { $0.hasPrefix("training-reminder-") })
  }

  @Test("Preferences are stored per student and never bleed across accounts")
  func perStudentPreferences() throws {
    let harness = try makeServices(center: FakeTrainingReminderNotificationCenter())
    let studentA = UUID()
    let studentB = UUID()
    var settingsA = TrainingReminderSettings.defaultValue
    settingsA.isEnabled = true
    settingsA.hour = 7

    harness.store.setSettings(settingsA, for: studentA)

    #expect(harness.store.settings(for: studentA) == settingsA)
    #expect(harness.store.settings(for: studentB) == .defaultValue)
  }

  private func makeServices(
    center: FakeTrainingReminderNotificationCenter
  ) throws -> ServicesHarness {
    let suiteName = "TrainingReminderRecoveryTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let store = TrainingReminderUserDefaultsStore(defaults: defaults)
    return ServicesHarness(
      services: TrainingReminderServices(store: store, center: center),
      store: store
    )
  }

  @MainActor
  private func makeViewModel(
    center: FakeTrainingReminderNotificationCenter
  ) throws -> ViewModelFixture {
    let harness = try makeServices(center: center)
    let studentID = UUID()
    return ViewModelFixture(
      viewModel: TrainingReminderSettingsViewModel(
        studentID: studentID,
        services: harness.services
      ),
      store: harness.store,
      studentID: studentID
    )
  }
}
