import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func completionMutationsIgnoreDuplicateCallsWhileRequestIsInFlight() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = SlowCompletionMutationRepository(plan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: cursorID, studentID: studentID)

  let firstComplete = Task { await viewModel.completeCurrentDay() }
  await plans.waitUntilCompleteStarted()
  let duplicateComplete = Task { await viewModel.completeCurrentDay() }
  await Task.yield()

  #expect(await plans.completeCallCount == 1)
  await plans.releaseComplete()
  #expect(await firstComplete.value)
  #expect(!(await duplicateComplete.value))

  let firstUndo = Task { await viewModel.undoCurrentDayCompletion() }
  await plans.waitUntilUndoStarted()
  let duplicateUndo = Task { await viewModel.undoCurrentDayCompletion() }
  await Task.yield()

  #expect(await plans.undoCallCount == 1)
  await plans.releaseUndo()
  #expect(await firstUndo.value)
  #expect(!(await duplicateUndo.value))
}

private actor SlowCompletionMutationRepository: StudentPlanRepository {
  private var plan: StudentPlanView
  private var canComplete = false
  private var canUndo = false
  private var completeGateWaiters: [CheckedContinuation<Void, Never>] = []
  private var undoGateWaiters: [CheckedContinuation<Void, Never>] = []
  private var completeStartWaiters: [CheckedContinuation<Void, Never>] = []
  private var undoStartWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var completeCallCount = 0
  private(set) var undoCallCount = 0

  init(plan: StudentPlanView) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plan
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plan
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plan.days
  }

  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    completeCallCount += 1
    resume(&completeStartWaiters)
    if !canComplete {
      await withCheckedContinuation { completeGateWaiters.append($0) }
    }
    let completedAt = Date(timeIntervalSince1970: 2_000_000_000)
    replaceDay(id: id, completedAt: completedAt, source: "manual")
    return PlanDayCompletion(
      id: UUID(),
      dayID: id,
      studentID: studentID,
      source: "manual",
      completedAt: completedAt
    )
  }

  func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    undoCallCount += 1
    resume(&undoStartWaiters)
    if !canUndo {
      await withCheckedContinuation { undoGateWaiters.append($0) }
    }
    replaceDay(id: id, completedAt: nil, source: nil)
  }

  func waitUntilCompleteStarted() async {
    guard completeCallCount == 0 else { return }
    await withCheckedContinuation { completeStartWaiters.append($0) }
  }

  func waitUntilUndoStarted() async {
    guard undoCallCount == 0 else { return }
    await withCheckedContinuation { undoStartWaiters.append($0) }
  }

  func releaseComplete() {
    canComplete = true
    resume(&completeGateWaiters)
  }

  func releaseUndo() {
    canUndo = true
    resume(&undoGateWaiters)
  }

  private func replaceDay(id: UUID, completedAt: Date?, source: String?) {
    plan = StudentPlanView(
      cycleID: plan.cycleID,
      weekIndex: plan.weekIndex,
      startDate: plan.startDate,
      endDate: plan.endDate,
      planKind: plan.planKind,
      publishedAt: plan.publishedAt,
      totalShiftDays: plan.totalShiftDays,
      latestShiftCreatedAt: plan.latestShiftCreatedAt,
      days: plan.days.map { day in
        day.id == id
          ? day.replacingCompletion(completedAt: completedAt, source: source)
          : day
      }
    )
  }

  private func resume(_ waiters: inout [CheckedContinuation<Void, Never>]) {
    for waiter in waiters {
      waiter.resume()
    }
    waiters = []
  }
}
