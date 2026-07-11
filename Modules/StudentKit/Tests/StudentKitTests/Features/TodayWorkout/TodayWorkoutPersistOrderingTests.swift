import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// recordSet blocks until `open()`, recording the order of completed flags —
/// lets tests overlap a video-mint persist with a user commit deterministically.
private actor GatedTrainingLogRepository: StudentTrainingLogRepository {
  private var gateOpen = false
  private var gateWaiters: [CheckedContinuation<Void, Never>] = []
  private var inFlightWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var recordedCompletedFlags: [Bool] = []
  private(set) var recordedWeights: [Decimal] = []

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    recordedCompletedFlags.append(log.completed)
    recordedWeights.append(log.weightKg)
    for waiter in inFlightWaiters { waiter.resume() }
    inFlightWaiters = []
    if !gateOpen {
      await withCheckedContinuation { gateWaiters.append($0) }
    }
    return log
  }

  func open() {
    gateOpen = true
    for waiter in gateWaiters { waiter.resume() }
    gateWaiters = []
  }

  func waitUntilInFlight() async {
    if !recordedCompletedFlags.isEmpty { return }
    await withCheckedContinuation { inFlightWaiters.append($0) }
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID, planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

@MainActor
@Test func overlappingVideoMintAndCompleteApplyInOrder() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let gated = GatedTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: gated,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  // Video attach mints a set log; its recordSet hangs on the gate.
  let mint = Task { await viewModel.ensureLoggedSetID(rowIndex: 0) }
  await gated.waitUntilInFlight()

  // The sheet stays alive mid-persist now: user edits and completes the set.
  viewModel.updateWeight(rowIndex: 0, weight: 105)
  let commit = Task { await viewModel.commitSet(rowIndex: 0) }
  for _ in 0..<5 { await Task.yield() }
  // Serialization proof: the commit must not reach the repository while the
  // mint's recordSet is still gated.
  #expect(await gated.recordedCompletedFlags == [false])
  await gated.open()

  #expect(await mint.value != nil)
  #expect(await commit.value)
  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state after overlapping persists")
    return
  }
  #expect(drafts[0].completed)
  #expect(drafts[0].actualWeight == 105)
  #expect(await gated.recordedCompletedFlags == [false, true])
  #expect(await gated.recordedWeights.last == 105)
}

@MainActor
@Test func stalePersistDoesNotTouchReloadedState() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let gated = GatedTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: gated,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  let mint = Task { await viewModel.ensureLoggedSetID(rowIndex: 0) }
  await gated.waitUntilInFlight()

  // Reload while the persist is in flight: the load generation moves on, so
  // the stale completion must not merge its flags into the fresh drafts.
  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  await gated.open()
  _ = await mint.value

  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state after reload")
    return
  }
  #expect(drafts[0].loggedSetID == nil)
  #expect(!drafts[0].completed)
}
