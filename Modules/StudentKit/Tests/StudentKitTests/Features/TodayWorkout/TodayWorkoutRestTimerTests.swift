import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// Spec 030 §B2 invariants, run against a frozen injected clock.
///
/// Frozen at the seed's own UTC-midnight anchor so `day[3].date == frozenNow`
/// and "today" resolves to day-offset 3 in every timezone at every hour
/// (mechanism documented in TodayWorkoutPRHookTests).
private let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)  // 2026-01-13 00:00:00 UTC

@MainActor
private func makeViewModel(
  now: Date = frozenNow,
  plan: StudentPlanView = StudentDemoSeed.makePlanView(today: frozenNow),
  restTimerSettings: (any StudentRestTimerSettingsStoring)? = nil,
  restTimerActivityController: any RestTimerActivityControlling =
    NoOpRestTimerActivityController()
) async throws -> TodayWorkoutViewModel {
  let studentID = StudentDemoSeed.studentID
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let settings = try restTimerSettings ?? testRestTimerSettingsStore().store
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: InMemoryE1RMRepository(),
    restTimerSettings: settings,
    restTimerActivityController: restTimerActivityController,
    now: { now }
  )
  await viewModel.load(date: frozenNow, studentID: studentID)
  guard case .loaded = viewModel.state else {
    throw RestTimerTestFailure("expected loaded, got \(viewModel.state)")
  }
  return viewModel
}

private struct RestTimerTestFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

@MainActor
private final class RestTimerActivityControllerSpy: RestTimerActivityControlling {
  enum Event: Equatable {
    case start(endsAt: Date, totalSeconds: Int)
    case update(endsAt: Date, totalSeconds: Int)
    case end
  }

  private(set) var events: [Event] = []

  func start(endsAt: Date, totalSeconds: Int) {
    events.append(.start(endsAt: endsAt, totalSeconds: totalSeconds))
  }

  func update(endsAt: Date, totalSeconds: Int) {
    events.append(.update(endsAt: endsAt, totalSeconds: totalSeconds))
  }

  func end() {
    events.append(.end)
  }
}

@MainActor
@Test func allDayCompletionNeverStartsRestOrLiveActivity() async throws {
  let activity = RestTimerActivityControllerSpy()
  let model = try await makeViewModel(restTimerActivityController: activity)
  #expect(activity.events == [.end])
  await model.toggleComplete(rowIndex: 0)
  await model.toggleComplete(rowIndex: 1)
  #expect(model.restTimer == nil)
  #expect(!model.showsRestTimerExplanation)
  #expect(activity.events == [.end])
  model.adjustRestTimer(bySeconds: 30)
  #expect(activity.events == [.end])
}

@MainActor
@Test func allDayRetainsPreferencesWithoutStartingTheirTimers() async throws {
  let settings = try testRestTimerSettingsStore()
  settings.store.setPreference(
    .custom(lowSeconds: 105, midSeconds: 195, highSeconds: 300),
    for: StudentDemoSeed.studentID)
  let model = try await makeViewModel(
    plan: planReplacingFirstSet(restSeconds: 75), restTimerSettings: settings.store)
  model.updateRPE(rowIndex: 0, rpe: 10)
  await model.toggleComplete(rowIndex: 0)
  #expect(model.restTimer == nil)
  #expect(!model.showsRestTimerExplanation)
  #expect(
    settings.store.preference(for: StudentDemoSeed.studentID)
      == .custom(lowSeconds: 105, midSeconds: 195, highSeconds: 300))
}

private func planReplacingFirstSet(restSeconds: Int?) -> StudentPlanView {
  let plan = StudentDemoSeed.makePlanView(today: frozenNow)
  let calendar = Calendar.current
  guard
    let dayIndex = plan.days.firstIndex(where: {
      calendar.isDate($0.date, inSameDayAs: frozenNow)
    })
  else {
    return plan
  }
  let day = plan.days[dayIndex]
  guard
    let exercise = day.exercises.first,
    let firstSet = exercise.prescribedSets.first
  else { return plan }

  var prescribedSets = exercise.prescribedSets
  prescribedSets[0] = PrescribedSet(
    id: firstSet.id,
    setIndex: firstSet.setIndex,
    weightKg: firstSet.weightKg,
    reps: firstSet.reps,
    repsMax: firstSet.repsMax,
    rpe: firstSet.rpe,
    restSeconds: restSeconds
  )
  var exercises = day.exercises
  exercises[0] = StudentPlanExercise(
    id: exercise.id,
    exercise: exercise.exercise,
    sequenceIndex: exercise.sequenceIndex,
    prescribedSets: prescribedSets
  )
  var days = plan.days
  days[dayIndex] = StudentPlanDay(id: day.id, date: day.date, exercises: exercises)
  return StudentPlanView(
    cycleID: plan.cycleID,
    weekIndex: plan.weekIndex,
    startDate: plan.startDate,
    planKind: plan.planKind,
    days: days
  )
}

private func testRestTimerSettingsStore() throws -> (
  store: UserDefaultsRestTimerSettingsStore, defaults: UserDefaults
) {
  let suiteName = "test.student-rest-timer.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  return (UserDefaultsRestTimerSettingsStore(defaults: defaults), defaults)
}
