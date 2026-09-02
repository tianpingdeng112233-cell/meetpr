import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func trainingPlanRefreshAppliesChangedDayAndKeepsUnsubmittedDraft() async throws {
  let studentID = StudentDemoSeed.studentID
  let initialPlan = StudentDemoSeed.makePlanView()
  let selectedDay = try #require(StudentPlanSequence.cursorDay(in: initialPlan))
  let refreshedPlan = try planByAppendingSet(to: selectedDay.id, in: initialPlan)
  let plans = SequencedRefreshStudentPlanRepository(
    initialPlan: initialPlan,
    refreshedPlan: refreshedPlan
  )
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: selectedDay.id, studentID: studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 181.5)

  await viewModel.refreshCurrentPlan(dayID: selectedDay.id, studentID: studentID)

  guard case .loaded(let day, let drafts) = viewModel.state else {
    Issue.record("Expected refreshed workout to remain loaded")
    return
  }
  #expect(day.exercises[0].prescribedSets.count == 4)
  #expect(drafts.count == 4)
  #expect(drafts[0].actualWeight == 181.5)
  #expect(drafts[0].actualReps == 6)
  #expect(await plans.refreshCallCount == 1)
}

@MainActor
@Test func trainingPlanRefreshSkipsASecondRequestInsideTheSharedInterval() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let selectedDay = try #require(StudentPlanSequence.cursorDay(in: plan))
  let plans = SequencedRefreshStudentPlanRepository(initialPlan: plan, refreshedPlan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: selectedDay.id, studentID: studentID)
  let firstTrigger = Date(timeIntervalSince1970: 2_000_000_000)

  await viewModel.refreshCurrentPlanIfAllowed(
    dayID: selectedDay.id,
    studentID: studentID,
    at: firstTrigger
  )
  await viewModel.refreshCurrentPlanIfAllowed(
    dayID: selectedDay.id,
    studentID: studentID,
    at: firstTrigger.addingTimeInterval(StudentTodayRefreshThrottle.interval - 1)
  )

  #expect(await plans.refreshCallCount == 1)
}

@MainActor
@Test func recordingThatStartsDuringRefreshKeepsTheVisibleWorkoutGeneration() async throws {
  let studentID = StudentDemoSeed.studentID
  let initialPlan = StudentDemoSeed.makePlanView()
  let selectedDay = try #require(StudentPlanSequence.cursorDay(in: initialPlan))
  let refreshedPlan = try planByAppendingSet(to: selectedDay.id, in: initialPlan)
  let plans = GatedFirstRefreshStudentPlanRepository(
    initialPlan: initialPlan,
    refreshedPlan: refreshedPlan
  )
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: selectedDay.id, studentID: studentID)

  let refreshTask = Task {
    await viewModel.refreshCurrentPlan(dayID: selectedDay.id, studentID: studentID)
  }
  await plans.waitUntilFirstRefreshStarts()
  #expect(await viewModel.commitSet(rowIndex: 0))
  await plans.finishFirstRefresh()
  await refreshTask.value

  guard case .loaded(let day, let drafts) = viewModel.state else {
    Issue.record("Expected the recorded workout to remain loaded")
    return
  }
  #expect(day == selectedDay)
  #expect(drafts[0].completed)
}

@MainActor
@Test func emptyRefreshKeepsTheLoadedWorkoutAndItsDraft() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let selectedDay = try #require(StudentPlanSequence.cursorDay(in: plan))
  let plans = EmptyRefreshStudentPlanRepository(initialPlan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: selectedDay.id, studentID: studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 142.5)

  await viewModel.refreshCurrentPlan(dayID: selectedDay.id, studentID: studentID)

  guard case .loaded(let day, let drafts) = viewModel.state else {
    Issue.record("An empty refresh must not replace the loaded workout")
    return
  }
  #expect(day == selectedDay)
  #expect(drafts[0].actualWeight == 142.5)
  #expect(viewModel.planDays.isEmpty == false)
  #expect(await plans.refreshCallCount == 1)
}

private actor EmptyRefreshStudentPlanRepository: StudentPlanRepository {
  private let initialPlan: StudentPlanView
  private(set) var refreshCallCount = 0

  init(initialPlan: StudentPlanView) {
    self.initialPlan = initialPlan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    initialPlan
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    refreshCallCount += 1
    return nil
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    initialPlan.days
  }
}

private actor SequencedRefreshStudentPlanRepository: StudentPlanRepository {
  private let initialPlan: StudentPlanView
  private let refreshedPlan: StudentPlanView
  private(set) var refreshCallCount = 0

  init(initialPlan: StudentPlanView, refreshedPlan: StudentPlanView) {
    self.initialPlan = initialPlan
    self.refreshedPlan = refreshedPlan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    initialPlan
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    refreshCallCount += 1
    return refreshedPlan
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    refreshedPlan.days
  }
}

private actor GatedFirstRefreshStudentPlanRepository: StudentPlanRepository {
  private let initialPlan: StudentPlanView
  private let refreshedPlan: StudentPlanView
  private var refreshCallCount = 0
  private var firstRefreshStarted = false
  private var firstRefreshContinuation: CheckedContinuation<Void, Never>?
  private var startWaiters: [CheckedContinuation<Void, Never>] = []

  init(initialPlan: StudentPlanView, refreshedPlan: StudentPlanView) {
    self.initialPlan = initialPlan
    self.refreshedPlan = refreshedPlan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    initialPlan
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    refreshCallCount += 1
    guard refreshCallCount == 1 else { return initialPlan }
    firstRefreshStarted = true
    for waiter in startWaiters { waiter.resume() }
    startWaiters = []
    await withCheckedContinuation { firstRefreshContinuation = $0 }
    return refreshedPlan
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    initialPlan.days
  }

  func waitUntilFirstRefreshStarts() async {
    guard !firstRefreshStarted else { return }
    await withCheckedContinuation { startWaiters.append($0) }
  }

  func finishFirstRefresh() {
    firstRefreshContinuation?.resume()
    firstRefreshContinuation = nil
  }
}

private func planByAppendingSet(
  to dayID: UUID,
  in plan: StudentPlanView
) throws -> StudentPlanView {
  let day = try #require(plan.days.first { $0.id == dayID })
  let exercise = try #require(day.exercises.first)
  let updatedExercise = try exerciseByAppendingSet(exercise)
  let updatedDay = StudentPlanDay(
    id: day.id,
    weekNumber: day.weekNumber,
    dayOfWeek: day.dayOfWeek,
    sortOrder: day.sortOrder,
    date: day.scheduledDate,
    shiftedToDate: day.shiftedToDate,
    completedAt: day.completedAt,
    completionSource: day.completionSource,
    exercises: [updatedExercise] + day.exercises.dropFirst()
  )
  return StudentPlanView(
    cycleID: plan.cycleID,
    weekIndex: plan.weekIndex,
    startDate: plan.startDate,
    endDate: plan.endDate,
    planKind: plan.planKind,
    publishedAt: plan.publishedAt,
    totalShiftDays: plan.totalShiftDays,
    latestShiftCreatedAt: plan.latestShiftCreatedAt,
    days: plan.days.map { $0.id == dayID ? updatedDay : $0 }
  )
}

private func exerciseByAppendingSet(
  _ exercise: StudentPlanExercise
) throws -> StudentPlanExercise {
  let firstSet = try #require(exercise.prescribedSets.first)
  let updatedFirstSet = PrescribedSet(
    id: firstSet.id,
    setIndex: firstSet.setIndex,
    weightKg: firstSet.weightKg,
    intensity: firstSet.intensity,
    percentageAnchor: firstSet.percentageAnchor,
    loadMode: firstSet.loadMode,
    reps: 6,
    repsMax: firstSet.repsMax,
    restSeconds: firstSet.restSeconds,
    coachNote: firstSet.coachNote
  )
  let appendedSet = PrescribedSet(
    id: UUID(),
    setIndex: exercise.prescribedSets.count,
    weightKg: 180,
    reps: 6,
    rpe: 8
  )
  let updatedExercise = StudentPlanExercise(
    id: exercise.id,
    exercise: exercise.exercise,
    sequenceIndex: exercise.sequenceIndex,
    prescribedSets: [updatedFirstSet] + exercise.prescribedSets.dropFirst() + [appendedSet],
    notes: exercise.notes
  )
  return updatedExercise
}
