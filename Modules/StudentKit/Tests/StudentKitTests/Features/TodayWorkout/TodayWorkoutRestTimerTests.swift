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
@Test func completionEdgeStartsTimerWithRPEDuration() async throws {
  let activityController = RestTimerActivityControllerSpy()
  let viewModel = try await makeViewModel(
    now: frozenNow,
    restTimerActivityController: activityController
  )

  // Demo "today" is the 硬拉 day: 3 sets @ RPE 8.5 → 180s per the policy.
  await viewModel.toggleComplete(rowIndex: 0)

  let timer = try #require(viewModel.restTimer)
  #expect(timer.totalSeconds == 180)
  #expect(timer.endsAt == frozenNow.addingTimeInterval(180))
  #expect(
    activityController.events == [
      .start(endsAt: timer.endsAt, totalSeconds: timer.totalSeconds)
    ]
  )
}

@MainActor
@Test func completionEdgePrefersPrescribedRestSecondsOverStudentPreference() async throws {
  let plan = planReplacingFirstSet(restSeconds: 75)
  let settings = try testRestTimerSettingsStore()
  settings.store.setPreference(
    .custom(lowSeconds: 105, midSeconds: 195, highSeconds: 300),
    for: StudentDemoSeed.studentID
  )
  let viewModel = try await makeViewModel(
    now: frozenNow, plan: plan, restTimerSettings: settings.store)

  viewModel.updateRPE(rowIndex: 0, rpe: 10)
  await viewModel.toggleComplete(rowIndex: 0)

  let timer = try #require(viewModel.restTimer)
  #expect(timer.totalSeconds == 75)
  #expect(timer.endsAt == frozenNow.addingTimeInterval(75))
}

@MainActor
@Test(
  "Custom preference uses actual RPE bands",
  arguments: [
    (Optional<Decimal>.none, 195),
    (Decimal(string: "6.5"), 105),
    (Decimal(7), 195),
    (Decimal(string: "8.5"), 195),
    (Decimal(9), 300),
  ]
)
func completionEdgeUsesStudentCustomBandBeforeAutoPolicy(
  actualRPE: Decimal?,
  expectedSeconds: Int
) async throws {
  let settings = try testRestTimerSettingsStore()
  settings.store.setPreference(
    .custom(lowSeconds: 105, midSeconds: 195, highSeconds: 300),
    for: StudentDemoSeed.studentID
  )
  let viewModel = try await makeViewModel(
    now: frozenNow, restTimerSettings: settings.store)

  viewModel.updateRPE(rowIndex: 0, rpe: actualRPE)
  await viewModel.toggleComplete(rowIndex: 0)

  let timer = try #require(viewModel.restTimer)
  #expect(timer.totalSeconds == expectedSeconds)
  #expect(timer.endsAt == frozenNow.addingTimeInterval(TimeInterval(expectedSeconds)))
}

@MainActor
@Test func explanationIsAcknowledgedOnceAcrossViewModels() async throws {
  let settings = try testRestTimerSettingsStore()
  let firstViewModel = try await makeViewModel(restTimerSettings: settings.store)

  await firstViewModel.toggleComplete(rowIndex: 0)
  #expect(firstViewModel.showsRestTimerExplanation)
  firstViewModel.acknowledgeRestTimerExplanation()
  #expect(!firstViewModel.showsRestTimerExplanation)

  let nextViewModel = try await makeViewModel(restTimerSettings: settings.store)
  await nextViewModel.toggleComplete(rowIndex: 0)
  #expect(!nextViewModel.showsRestTimerExplanation)
}

@MainActor
@Test func editingAlreadyCompletedSetDoesNotRestartTimer() async throws {
  let activityController = RestTimerActivityControllerSpy()
  let viewModel = try await makeViewModel(
    restTimerActivityController: activityController
  )

  await viewModel.toggleComplete(rowIndex: 0)
  let started = try #require(viewModel.restTimer)
  viewModel.skipRestTimer()
  #expect(viewModel.restTimer == nil)
  #expect(
    activityController.events == [
      .start(endsAt: started.endsAt, totalSeconds: started.totalSeconds),
      .end,
    ]
  )

  // commitSet on an already-completed row persists edits — no new edge,
  // and no further activity traffic.
  let eventsBeforeCommit = activityController.events.count
  await viewModel.commitSet(rowIndex: 0)
  #expect(viewModel.restTimer == nil)
  #expect(activityController.events.count == eventsBeforeCommit)
}

@MainActor
@Test func consecutiveCompletionsReplaceTheTimer() async throws {
  let activityController = RestTimerActivityControllerSpy()
  let viewModel = try await makeViewModel(
    now: frozenNow,
    restTimerActivityController: activityController
  )

  await viewModel.toggleComplete(rowIndex: 0)
  let first = try #require(viewModel.restTimer)
  await viewModel.toggleComplete(rowIndex: 1)
  let second = try #require(viewModel.restTimer)
  #expect(first == second || second.endsAt >= first.endsAt)
  #expect(second.totalSeconds == 180)
  #expect(
    activityController.events == [
      .start(endsAt: first.endsAt, totalSeconds: first.totalSeconds),
      .end,
      .start(endsAt: second.endsAt, totalSeconds: second.totalSeconds),
    ]
  )
}

@MainActor
@Test func lastSetOfTheDayDoesNotStartTimer() async throws {
  let activityController = RestTimerActivityControllerSpy()
  let viewModel = try await makeViewModel(
    restTimerActivityController: activityController
  )
  guard case .loaded(_, let drafts) = viewModel.state else {
    throw RestTimerTestFailure("not loaded")
  }

  for index in drafts.indices.dropLast() {
    await viewModel.toggleComplete(rowIndex: index)
  }
  let eventsBeforeFinalSet = activityController.events.count
  let lastIndex = try #require(drafts.indices.last)
  await viewModel.toggleComplete(rowIndex: lastIndex)
  #expect(viewModel.restTimer == nil, "completion banner takes over after the final set")
  #expect(
    Array(activityController.events.dropFirst(eventsBeforeFinalSet)) == [.end],
    "the final set must end the activity without starting a new one"
  )
}

@MainActor
@Test func adjustClampsRemainingBetweenZeroAnd900() async throws {
  let activityController = RestTimerActivityControllerSpy()
  let viewModel = try await makeViewModel(
    now: frozenNow,
    restTimerActivityController: activityController
  )
  await viewModel.toggleComplete(rowIndex: 0)

  viewModel.adjustRestTimer(bySeconds: 30)
  #expect(
    activityController.events.last
      == .update(endsAt: frozenNow.addingTimeInterval(210), totalSeconds: 180)
  )

  viewModel.adjustRestTimer(bySeconds: -30)
  #expect(
    activityController.events.last
      == .update(endsAt: frozenNow.addingTimeInterval(180), totalSeconds: 180)
  )

  // Repeated positive adjustments clamp at 900s remaining.
  for _ in 0..<40 { viewModel.adjustRestTimer(bySeconds: 30) }
  let maxed = try #require(viewModel.restTimer)
  #expect(maxed.endsAt == frozenNow.addingTimeInterval(900))
  #expect(
    activityController.events.last
      == .update(endsAt: maxed.endsAt, totalSeconds: maxed.totalSeconds)
  )

  // Large negative clamps at 0 (immediately finished, not negative).
  viewModel.adjustRestTimer(bySeconds: -10_000)
  let floored = try #require(viewModel.restTimer)
  #expect(floored.endsAt == frozenNow)
  #expect(
    activityController.events.last
      == .update(endsAt: floored.endsAt, totalSeconds: floored.totalSeconds)
  )

  viewModel.skipRestTimer()
  #expect(viewModel.restTimer == nil)
  #expect(activityController.events.last == .end)
  let eventsAfterSkip = activityController.events.count
  viewModel.adjustRestTimer(bySeconds: 30)
  #expect(viewModel.restTimer == nil, "adjust on a dismissed timer is a no-op")
  #expect(
    activityController.events.count == eventsAfterSkip,
    "a dismissed timer must not emit activity traffic on adjust"
  )
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
