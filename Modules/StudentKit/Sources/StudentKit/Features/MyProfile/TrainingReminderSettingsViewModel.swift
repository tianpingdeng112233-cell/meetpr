import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
final class TrainingReminderSettingsViewModel {
  private(set) var settings: TrainingReminderSettings
  private(set) var showsPermissionDenied = false
  private(set) var showsScheduleFailure = false
  private(set) var isChangingAuthorization = false
  private(set) var isLoadingDefaults = false

  @ObservationIgnored private let studentID: UUID
  @ObservationIgnored private let services: TrainingReminderServices
  @ObservationIgnored private let plans: (any StudentPlanRepository)?
  @ObservationIgnored private let recommendedWeekdays: Set<TrainingReminderWeekday>?

  init(
    studentID: UUID,
    services: TrainingReminderServices,
    recommendedWeekdays: Set<TrainingReminderWeekday>? = nil,
    plans: (any StudentPlanRepository)? = nil
  ) {
    self.studentID = studentID
    self.services = services
    self.plans = plans
    self.recommendedWeekdays = recommendedWeekdays
    self.settings =
      services.store.storedSettings(for: studentID)
      ?? .initial(recommendedWeekdays: recommendedWeekdays)
  }

  func synchronize() async {
    guard !isLoadingDefaults else { return }
    isLoadingDefaults = true
    defer { isLoadingDefaults = false }
    if services.store.storedSettings(for: studentID) == nil {
      let plan = try? await plans?.refreshCurrentPlan(studentID: studentID)
      settings = .initial(
        recommendedWeekdays: recommendedWeekdays,
        plan: plan,
        storedSettings: services.store.storedSettings(for: studentID)
      )
    }
    let outcome = await TrainingReminderBootstrap.reconcile(
      studentID: studentID,
      services: services
    )
    // Keep the unpersisted recommended defaults when nothing is stored yet.
    settings = services.store.storedSettings(for: studentID) ?? settings
    switch outcome {
    case .disabledByPermission(let denied):
      showsPermissionDenied = denied
    case .scheduleFailed:
      showsScheduleFailure = true
    case .cleared, .scheduled:
      break
    }
  }

  /// Re-checks authorization when the app returns to the foreground so the
  /// denied banner clears right after the user flips the system toggle.
  func refreshAuthorization() async {
    let authorization = await services.center.authorizationStatus()
    if authorization == .authorized {
      showsPermissionDenied = false
    } else if settings.isEnabled {
      var disabledSettings = settings
      disabledSettings.isEnabled = false
      showsPermissionDenied = authorization == .denied
      await persistAndSchedule(disabledSettings)
    }
  }

  func setEnabled(_ isEnabled: Bool) async {
    guard settings.isEnabled != isEnabled else { return }
    guard isEnabled else {
      var newSettings = settings
      newSettings.isEnabled = false
      await persistAndSchedule(newSettings)
      return
    }

    isChangingAuthorization = true
    defer { isChangingAuthorization = false }

    let authorization = await services.center.authorizationStatus()
    let isAuthorized: Bool
    switch authorization {
    case .authorized:
      isAuthorized = true
    case .denied:
      isAuthorized = false
    case .notDetermined:
      isAuthorized = (try? await services.center.requestAuthorization()) == true
    }

    var newSettings = settings
    newSettings.isEnabled = isAuthorized
    showsPermissionDenied = !isAuthorized
    await persistAndSchedule(newSettings)
  }

  func toggle(_ weekday: TrainingReminderWeekday) async {
    var newSettings = settings
    if newSettings.weekdays.contains(weekday) {
      newSettings.weekdays.remove(weekday)
    } else {
      newSettings.weekdays.insert(weekday)
    }
    await persistAndSchedule(newSettings)
  }

  func setTime(hour: Int, minute: Int) async {
    guard (0...23).contains(hour), (0...59).contains(minute) else { return }
    var newSettings = settings
    newSettings.hour = hour
    newSettings.minute = minute
    await persistAndSchedule(newSettings)
  }

  private func persistAndSchedule(_ newSettings: TrainingReminderSettings) async {
    showsScheduleFailure = false
    settings = newSettings
    services.store.setSettings(newSettings, for: studentID)
    guard await services.scheduler.replace(with: newSettings) else {
      // The scheduler rolled the pending set back to empty; fall the stored
      // preference back to off so persisted state matches reality.
      var fallback = newSettings
      fallback.isEnabled = false
      settings = fallback
      services.store.setSettings(fallback, for: studentID)
      showsScheduleFailure = true
      return
    }
  }
}
