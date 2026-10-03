import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func completionPresentsCelebrationWhileSendingThenConfirmsReceipt() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = SlowCompletionMutationRepository(plan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: cursorID, studentID: StudentDemoSeed.studentID)

  let completion = Task { await viewModel.completeCurrentDay() }
  await plans.waitUntilCompleteStarted()
  #expect(viewModel.completionPhase == .celebration)
  #expect(viewModel.isCompletionSending)
  #expect(try receiptText(viewModel) == "正在发送给教练…")

  await plans.releaseComplete()
  #expect(await completion.value)
  #expect(viewModel.completionPhase == .celebration)
  #expect(!viewModel.isCompletionSending)
  #expect(try receiptText(viewModel) == "教练已收到你的训练日志")
  #expect(viewModel.completionRevision == 1)
}

@MainActor
private func receiptText(_ viewModel: TodayWorkoutViewModel) throws -> String {
  guard case .loaded(let day, let drafts) = viewModel.state else {
    throw CompletionTestError.unexpectedState
  }
  return WorkoutCompletionPresentation(
    day: day, drafts: drafts, references: [:], weekCode: "W1D1", coachName: nil,
    isSendingToCoach: viewModel.isCompletionSending
  ).coachReceiptText
}

private enum CompletionTestError: Error {
  case unexpectedState
  case serviceUnavailable
}

@MainActor
@Test(arguments: [false, true])
func completionDoesNotReopenDismissedReward(failing: Bool) async throws {
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = SlowCompletionMutationRepository(plan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: cursorID, studentID: StudentDemoSeed.studentID)
  let completion = Task { await viewModel.completeCurrentDay() }
  await plans.waitUntilCompleteStarted()
  viewModel.completionPhase = nil
  await plans.releaseComplete(failing: failing)
  #expect(await completion.value == !failing)
  #expect(viewModel.completionPhase == nil)
  #expect(!viewModel.isCompletionSending)
  #expect((viewModel.actionErrorMessage != nil) == failing)
}

@MainActor
@Test func completionSendingReceiptIsLocalizedInBothLanguages() throws {
  let day = try #require(StudentPlanSequence.cursorDay(in: StudentDemoSeed.makePlanView()))
  for (locale, expected) in [
    ("zh-Hans", "正在发送给教练…"), ("en", "Sending to your coach…"),
  ] {
    let presentation = WorkoutCompletionPresentation(
      day: day, drafts: [], references: [:], weekCode: "W1D1", coachName: "Coach",
      isSendingToCoach: true, locale: Locale(identifier: locale)
    )
    #expect(presentation.coachReceiptText == expected)
  }
}

@MainActor
@Test func completionFailureClosesCelebrationPreservesSetsAndAllowsRetry() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = SlowCompletionMutationRepository(plan: plan)
  let viewModel = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(dayID: cursorID, studentID: StudentDemoSeed.studentID)
  await viewModel.toggleComplete(rowIndex: 0)
  let original = viewModel.state

  let completion = Task { await viewModel.completeCurrentDay() }
  await plans.waitUntilCompleteStarted()
  #expect(viewModel.completionPhase == .celebration)
  guard case .loaded(let pendingDay, _) = viewModel.state else {
    throw CompletionTestError.unexpectedState
  }
  #expect(pendingDay.completedAt != nil)
  await plans.releaseComplete(failing: true)
  #expect(!(await completion.value))
  #expect(viewModel.completionPhase == nil)
  #expect(!viewModel.isCompletionSending)
  #expect(viewModel.state == original)
  #expect(viewModel.actionErrorMessage == StudentStrings.localized(.todayWorkoutViewModel001))
  #expect(viewModel.completionRevision == 0)

  await plans.releaseComplete()
  #expect(await viewModel.completeCurrentDay())
  #expect(viewModel.actionErrorMessage == nil)
}

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

@MainActor
@Test func completionTimeoutRollsBackWithoutWaitingForUncooperativeRequest() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let cursorID = try #require(StudentPlanSequence.cursorDay(in: plan)?.id)
  let plans = SlowCompletionMutationRepository(plan: plan)
  let clock = CompletionTestClock()
  let viewModel = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository(),
    completionSleep: { await clock.sleep() }
  )
  await viewModel.load(dayID: cursorID, studentID: StudentDemoSeed.studentID)
  await viewModel.toggleComplete(rowIndex: 0)
  let original = viewModel.state
  let completion = Task { await viewModel.completeCurrentDay() }
  await plans.waitUntilCompleteStarted()
  await clock.waitUntilSleeping()
  #expect(viewModel.completionPhase == .celebration)
  await clock.fire()

  // This must return before the repository cooperates with cancellation.
  #expect(!(await completion.value))
  #expect(viewModel.completionPhase == nil)
  #expect(!viewModel.isCompletionSending)
  #expect(viewModel.state == original)
  #expect(viewModel.actionErrorMessage == StudentStrings.localized(.todayWorkoutViewModel001))
  await plans.releaseComplete()
  await Task.yield()
  #expect(viewModel.completionPhase == nil)
  #expect(viewModel.state == original)
  #expect(viewModel.completionRevision == 0)
}

private actor CompletionTestClock {
  private var sleeper: CheckedContinuation<Void, Never>?
  private var startWaiters: [CheckedContinuation<Void, Never>] = []

  func sleep() async {
    await withCheckedContinuation { continuation in
      sleeper = continuation
      for waiter in startWaiters { waiter.resume() }
      startWaiters = []
    }
  }

  func waitUntilSleeping() async {
    guard sleeper == nil else { return }
    await withCheckedContinuation { startWaiters.append($0) }
  }

  func fire() {
    sleeper?.resume()
    sleeper = nil
  }
}

private actor SlowCompletionMutationRepository: StudentPlanRepository {
  private var plan: StudentPlanView
  private var canComplete = false
  private var canUndo = false
  private var failsCompletion = false
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
    if failsCompletion { throw CompletionTestError.serviceUnavailable }
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

  func releaseComplete(failing: Bool = false) {
    failsCompletion = failing
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
