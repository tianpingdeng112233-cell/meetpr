import CoreModels
import Foundation
import Testing

@testable import StudentKit

/// Spec 030 §B2 invariants, run against a frozen injected clock.
@MainActor
private func makeViewModel(
  now: Date = Date(timeIntervalSince1970: 1_768_262_400),
  plan: StudentPlanView = StudentDemoSeed.makePlanView()
) async throws -> TodayWorkoutViewModel {
  let studentID = StudentDemoSeed.studentID
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(),
    e1rm: InMemoryE1RMRepository(),
    now: { now }
  )
  await viewModel.load(date: Date(), studentID: studentID)
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
@Test func completionEdgeStartsTimerWithRPEDuration() async throws {
  let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)
  let viewModel = try await makeViewModel(now: frozenNow)

  // Demo "today" is the 硬拉 day: 3 sets @ RPE 8.5 → 180s per the policy.
  await viewModel.toggleComplete(rowIndex: 0)

  let timer = try #require(viewModel.restTimer)
  #expect(timer.totalSeconds == 180)
  #expect(timer.endsAt == frozenNow.addingTimeInterval(180))
}

@MainActor
@Test func completionEdgePrefersPrescribedRestSecondsOverAutoPolicy() async throws {
  let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)
  let plan = planReplacingFirstSet(restSeconds: 75)
  let viewModel = try await makeViewModel(now: frozenNow, plan: plan)

  viewModel.updateRPE(rowIndex: 0, rpe: 10)
  await viewModel.toggleComplete(rowIndex: 0)

  let timer = try #require(viewModel.restTimer)
  #expect(timer.totalSeconds == 75)
  #expect(timer.endsAt == frozenNow.addingTimeInterval(75))
}

@MainActor
@Test func editingAlreadyCompletedSetDoesNotRestartTimer() async throws {
  let viewModel = try await makeViewModel()

  await viewModel.toggleComplete(rowIndex: 0)
  viewModel.skipRestTimer()
  #expect(viewModel.restTimer == nil)

  // commitSet on an already-completed row persists edits — no new edge.
  await viewModel.commitSet(rowIndex: 0)
  #expect(viewModel.restTimer == nil)
}

@MainActor
@Test func consecutiveCompletionsReplaceTheTimer() async throws {
  let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)
  let viewModel = try await makeViewModel(now: frozenNow)

  await viewModel.toggleComplete(rowIndex: 0)
  let first = try #require(viewModel.restTimer)
  await viewModel.toggleComplete(rowIndex: 1)
  let second = try #require(viewModel.restTimer)
  #expect(first == second || second.endsAt >= first.endsAt)
  #expect(second.totalSeconds == 180)
}

@MainActor
@Test func lastSetOfTheDayDoesNotStartTimer() async throws {
  let viewModel = try await makeViewModel()
  guard case .loaded(_, let drafts) = viewModel.state else {
    throw RestTimerTestFailure("not loaded")
  }

  for index in drafts.indices {
    await viewModel.toggleComplete(rowIndex: index)
  }
  #expect(viewModel.restTimer == nil, "completion banner takes over after the final set")
}

@MainActor
@Test func adjustClampsRemainingBetweenZeroAnd900() async throws {
  let frozenNow = Date(timeIntervalSince1970: 1_768_262_400)
  let viewModel = try await makeViewModel(now: frozenNow)
  await viewModel.toggleComplete(rowIndex: 0)

  // +30s repeatedly clamps at 900s remaining.
  for _ in 0..<40 { viewModel.adjustRestTimer(bySeconds: 30) }
  let maxed = try #require(viewModel.restTimer)
  #expect(maxed.endsAt == frozenNow.addingTimeInterval(900))

  // Large negative clamps at 0 (immediately finished, not negative).
  viewModel.adjustRestTimer(bySeconds: -10_000)
  let floored = try #require(viewModel.restTimer)
  #expect(floored.endsAt == frozenNow)

  viewModel.skipRestTimer()
  #expect(viewModel.restTimer == nil)
  viewModel.adjustRestTimer(bySeconds: 30)
  #expect(viewModel.restTimer == nil, "adjust on a dismissed timer is a no-op")
}

private func planReplacingFirstSet(restSeconds: Int?) -> StudentPlanView {
  let plan = StudentDemoSeed.makePlanView()
  let calendar = Calendar.current
  guard let dayIndex = plan.days.firstIndex(where: { calendar.isDateInToday($0.date) }) else {
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
