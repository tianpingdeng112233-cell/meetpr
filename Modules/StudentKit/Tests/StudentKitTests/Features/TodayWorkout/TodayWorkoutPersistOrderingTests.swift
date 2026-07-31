import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

/// recordSet blocks until `open()`, recording the order of completed flags —
/// lets tests overlap a video-mint persist with a user commit deterministically.
private actor GatedTrainingLogRepository: StudentTrainingLogRepository {
  private var storedLogs: [StudentSetLog]
  private var gateOpen = false
  private var gateWaiters: [CheckedContinuation<Void, Never>] = []
  private var inFlightWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var recordedCompletedFlags: [Bool] = []
  private(set) var recordedWeights: [Decimal] = []

  init(seed: [StudentSetLog] = []) {
    storedLogs = seed
  }

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    recordedCompletedFlags.append(log.completed)
    recordedWeights.append(log.weightKg)
    for waiter in inFlightWaiters { waiter.resume() }
    inFlightWaiters = []
    if !gateOpen {
      await withCheckedContinuation { gateWaiters.append($0) }
    }
    storedLogs.removeAll { $0.id == log.id }
    storedLogs.append(log)
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
    storedLogs.filter { $0.studentID == studentID && dateRange.contains($0.loggedAt) }
  }

  func fetchLogsForExercise(
    studentID: UUID, planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    storedLogs.filter {
      $0.studentID == studentID && $0.planExerciseID == planExerciseID
    }
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

@MainActor
@Test func stalePersistStillRecordsE1RMPointAfterReconcileReloadInterleaving() async throws {
  let prescribedSets = [
    PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8),
    PrescribedSet(id: UUID(), setIndex: 1, reps: 5, rpe: 8),
  ]
  let fixture = makeCoachRPEFixture(prescribedSets: prescribedSets)
  let originalLog = coachRPELog(
    fixture: fixture,
    weightKg: 140,
    rpe: 6,
    date: fixture.anchor
  )
  let canonicalLog = replacingCoachRPE(in: originalLog, with: 8)
  let logs = GatedTrainingLogRepository(seed: [canonicalLog])
  let e1rm = InMemoryE1RMRepository()
  await recordCoachRPEPoint(log: originalLog, fixture: fixture, in: e1rm)
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.plans,
    logs: logs,
    e1rm: e1rm,
    onboarding: fixture.onboarding,
    now: { fixture.anchor.addingTimeInterval(60) }
  )
  await viewModel.load(date: fixture.anchor, studentID: fixture.studentID)
  viewModel.updateWeight(rowIndex: 1, weight: 150)
  viewModel.updateReps(rowIndex: 1, reps: 5)
  viewModel.updateRPE(rowIndex: 1, rpe: 8)

  let commit = Task { await viewModel.commitSet(rowIndex: 1) }
  await logs.waitUntilInFlight()

  let reconciler = makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)
  let reconciliation = try await reconciler.reconcile(studentID: fixture.studentID)
  #expect(reconciliation.didReconcile)
  await viewModel.load(date: fixture.anchor, studentID: fixture.studentID)

  await logs.open()
  #expect(await commit.value)

  let points = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  #expect(points.contains { $0.sourceWeightKg == 150 && $0.sourceReps == 5 })
  #expect(viewModel.pendingPRBanner == nil)
}

@MainActor
// The explicit suspension points document and lock the full race ordering.
// swiftlint:disable:next function_body_length
@Test func reconcileCannotConsumeLivePRBeforeE1RMRecordingResumes() async throws {
  let prescribedSets = [
    PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8)
  ]
  let fixture = makeCoachRPEFixture(prescribedSets: prescribedSets)
  let logs = InMemoryStudentTrainingLogRepository()
  let backingE1RM = InMemoryE1RMRepository()
  let e1rm = ReconciliationSpyE1RMRepository(backing: backingE1RM)
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.plans,
    logs: logs,
    e1rm: e1rm,
    onboarding: fixture.onboarding,
    now: { fixture.anchor.addingTimeInterval(60) }
  )
  await viewModel.load(date: fixture.anchor, studentID: fixture.studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 150)
  viewModel.updateReps(rowIndex: 0, reps: 5)
  viewModel.updateRPE(rowIndex: 0, rpe: 8)

  await e1rm.pauseNextWeightBaseline()
  let commit = Task { await viewModel.commitSet(rowIndex: 0) }
  let pausedBaseline = try #require(await e1rm.waitUntilWeightBaselinePaused())

  let visibleLogs = try await logs.fetchLogs(
    studentID: fixture.studentID,
    in: fixture.anchor...fixture.anchor.addingTimeInterval(86_400)
  )
  let visibleLog = try #require(visibleLogs.first)
  #expect(visibleLog.id == pausedBaseline.setLogId)

  let reconciler = makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)
  let reconciliation = try await reconciler.reconcile(studentID: fixture.studentID)
  #expect(reconciliation.didReconcile)
  #expect(
    try await e1rm.prEvents(
      studentId: fixture.studentID,
      since: Date(timeIntervalSince1970: 0)
    ).isEmpty,
    "reconcile must remain silent"
  )

  await e1rm.resumeWeightBaseline()
  #expect(await commit.value)
  let firstEvent = try #require(viewModel.pendingPRBanner)
  #expect(firstEvent.setLogId == visibleLog.id)
  #expect(firstEvent.previousMaxE1RMKg == nil)
  #expect(
    firstEvent.previousMaxWeightKg == 0,
    "recovered PR must report the pre-replay record, not this set's own weight"
  )

  let recorder = E1RMRecorder(e1rm: e1rm, now: { visibleLog.loggedAt })
  let duplicateEvent = await recorder.record(
    E1RMRecorder.Input(
      studentID: fixture.studentID,
      exerciseID: fixture.exercise.id,
      family: .bench,
      setLogID: visibleLog.id,
      weightKg: visibleLog.weightKg,
      reps: visibleLog.reps,
      rpe: visibleLog.rpe,
      coachRPE: visibleLog.coachRPE,
      completed: visibleLog.completed,
      failed: visibleLog.failed
    )
  )
  let events = try await e1rm.prEvents(
    studentId: fixture.studentID,
    since: Date(timeIntervalSince1970: 0)
  )

  #expect(duplicateEvent == nil, "the same set log must not emit a second banner")
  #expect(events.count == 1)
  #expect(events.first?.id == firstEvent.id)
}
