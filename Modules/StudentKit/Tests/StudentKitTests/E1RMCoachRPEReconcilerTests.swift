import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func coachRPEReconciliationUpdatesSuggestionAndRevertsToStudentRPE() async throws {
  let fixture = makeCoachRPEFixture()
  let originalLog = coachRPELog(
    fixture: fixture,
    weightKg: 140,
    rpe: 6,
    date: fixture.anchor
  )
  let logs = InMemoryStudentTrainingLogRepository(seed: [originalLog])
  let e1rm = ReconciliationSpyE1RMRepository()
  await recordCoachRPEPoint(log: originalLog, fixture: fixture, in: e1rm)
  let reconciler = makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)

  let initialPoints = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  expectNoSuggestionBaseline(initialPoints)
  #expect(try await e1rm.fetchPRs(studentId: fixture.studentID, family: .bench).count == 1)

  let calibratedPoints = try await reconcileCalibration(
    originalLog: originalLog,
    fixture: fixture,
    logs: logs,
    e1rm: e1rm,
    reconciler: reconciler
  )
  try await expectIdempotent(
    reconciler: reconciler,
    e1rm: e1rm,
    fixture: fixture,
    calibratedPoints: calibratedPoints
  )

  try await reconcileReversion(
    originalLog: originalLog,
    fixture: fixture,
    logs: logs,
    e1rm: e1rm,
    reconciler: reconciler
  )
}

private func expectNoSuggestionBaseline(_ points: [E1RMHistoryPoint]) {
  #expect(E1RMSeries.trustedSuggestionEligibleRaw(points: points, family: .bench).isEmpty)
}

private func expectCalibrated(
  result: E1RMCoachRPEReconciler.Result,
  point: E1RMHistoryPoint,
  suggestion: Double?
) {
  #expect(result.didReconcile)
  #expect(point.sourceCoachRPE == 8)
  #expect(abs(point.e1RMKg - 179.49) < 0.01)
  #expect(suggestion != nil)
}

private func expectReverted(
  result: E1RMCoachRPEReconciler.Result,
  point: E1RMHistoryPoint,
  points: [E1RMHistoryPoint]
) {
  #expect(result.didReconcile)
  #expect(point.sourceCoachRPE == nil)
  #expect(abs(point.e1RMKg - 200) < 0.01)
  expectNoSuggestionBaseline(points)
}

private func expectIdempotent(
  reconciler: E1RMCoachRPEReconciler,
  e1rm: ReconciliationSpyE1RMRepository,
  fixture: CoachRPEFixture,
  calibratedPoints: [E1RMHistoryPoint]
) async throws {
  let replaceCallsBefore = await e1rm.conditionalReplaceCallCount
  let mutationCallsBefore = await e1rm.mutationCallCount
  let result = try await reconciler.reconcile(studentID: fixture.studentID)
  let points = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  #expect(result == .init(didReconcile: false, pointCount: 0))
  #expect(points.map(\.id) == calibratedPoints.map(\.id))
  #expect(await e1rm.conditionalReplaceCallCount == replaceCallsBefore)
  #expect(await e1rm.mutationCallCount == mutationCallsBefore)
}

private func reconcileCalibration(
  originalLog: StudentSetLog,
  fixture: CoachRPEFixture,
  logs: InMemoryStudentTrainingLogRepository,
  e1rm: ReconciliationSpyE1RMRepository,
  reconciler: E1RMCoachRPEReconciler
) async throws -> [E1RMHistoryPoint] {
  _ = try await logs.recordSet(replacingCoachRPE(in: originalLog, with: 8))
  let result = try await reconciler.reconcile(studentID: fixture.studentID)
  let points = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  let point = try #require(points.first)
  let baseline = try #require(
    E1RMSeries.trustedSuggestionEligibleRaw(points: points, family: .bench).first
  )
  let suggestion = E1RMCalculator.suggestedWeight(e1RM: baseline.e1RMKg, reps: 5, rpe: 8)
  expectCalibrated(result: result, point: point, suggestion: suggestion)
  #expect(try await e1rm.fetchPRs(studentId: fixture.studentID, family: .bench).count == 1)
  return points
}

private func reconcileReversion(
  originalLog: StudentSetLog,
  fixture: CoachRPEFixture,
  logs: InMemoryStudentTrainingLogRepository,
  e1rm: ReconciliationSpyE1RMRepository,
  reconciler: E1RMCoachRPEReconciler
) async throws {
  _ = try await logs.recordSet(originalLog)
  let result = try await reconciler.reconcile(studentID: fixture.studentID)
  let points = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  expectReverted(result: result, point: try #require(points.first), points: points)
  #expect(try await e1rm.fetchPRs(studentId: fixture.studentID, family: .bench).count == 1)
}

@Test func coachRPEReconciliationRebuildsConfidenceChronologically() async throws {
  let fixture = makeCoachRPEFixture()
  let originalLogs = [
    coachRPELog(fixture: fixture, weightKg: 100, rpe: 8, date: fixture.anchor),
    coachRPELog(
      fixture: fixture,
      setIndex: 1,
      weightKg: 120,
      rpe: 6,
      date: fixture.anchor.addingTimeInterval(60)
    ),
    coachRPELog(
      fixture: fixture,
      setIndex: 2,
      weightKg: 130,
      rpe: 10,
      date: fixture.anchor.addingTimeInterval(120)
    ),
  ]
  let logs = InMemoryStudentTrainingLogRepository(seed: originalLogs)
  let e1rm = InMemoryE1RMRepository()
  for log in originalLogs {
    await recordCoachRPEPoint(log: log, fixture: fixture, in: e1rm)
  }
  let before = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )
  #expect(before.map(\.confidence) == [.normal, .low, .low])

  _ = try await logs.recordSet(replacingCoachRPE(in: originalLogs[1], with: 10))
  let reconciler = makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)
  let result = try await reconciler.reconcile(studentID: fixture.studentID)
  let rebuilt = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )

  #expect(result.didReconcile)
  #expect(rebuilt.map(\.confidence) == [.normal, .normal, .normal])
  #expect(rebuilt[1].sourceCoachRPE == 10)
  #expect(rebuilt[2].e1RMKg > rebuilt[1].e1RMKg)
}

@Test func coachRPEReconciliationRebuildsMissingEligibleLocalPoint() async throws {
  let fixture = makeCoachRPEFixture()
  let canonicalLog = replacingCoachRPE(
    in: coachRPELog(
      fixture: fixture,
      weightKg: 140,
      rpe: 6,
      date: fixture.anchor
    ),
    with: 8
  )
  let logs = InMemoryStudentTrainingLogRepository(seed: [canonicalLog])
  let e1rm = ReconciliationSpyE1RMRepository()
  let reconciler = makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)

  let rebuilt = try await reconciler.reconcile(studentID: fixture.studentID)
  let points = try await e1rm.fetchHistory(
    studentId: fixture.studentID,
    exerciseId: fixture.exercise.id
  )

  #expect(rebuilt == .init(didReconcile: true, pointCount: 1))
  #expect(points.first?.setLogId == canonicalLog.id)
  #expect(points.first?.sourceCoachRPE == 8)

  let replaceCalls = await e1rm.conditionalReplaceCallCount
  let unchanged = try await reconciler.reconcile(studentID: fixture.studentID)
  #expect(unchanged == .init(didReconcile: false, pointCount: 0))
  #expect(await e1rm.conditionalReplaceCallCount == replaceCalls)
}

@Test func reconciliationAbandonsStaleReplacementWhenASetIsRecordedAfterSnapshot() async throws {
  let setup = try await makeInterleavingSetup()

  let abandoned = try await setup.reconciler.reconcile(studentID: setup.fixture.studentID)
  let historyAfterAbandon = try await setup.e1rm.fetchHistory(
    studentId: setup.fixture.studentID,
    exerciseId: setup.fixture.exercise.id
  )
  let baselineAfterAbandon = try #require(
    try await setup.e1rm.fetchWeightBaseline(studentId: setup.fixture.studentID, family: .bench)
  )
  let prsAfterAbandon = try await setup.e1rm.fetchPRs(
    studentId: setup.fixture.studentID,
    family: .bench
  )
  expectAbandonedReplacement(
    AbandonedReplacementSnapshot(
      result: abandoned,
      history: historyAfterAbandon,
      baseline: baselineAfterAbandon,
      prEvents: prsAfterAbandon,
      originalLogID: setup.originalLog.id,
      newLogID: setup.newLog.id,
      successfulReplaceCount: await setup.e1rm.successfulConditionalReplaceCount
    )
  )

  let retried = try await setup.reconciler.reconcile(studentID: setup.fixture.studentID)
  let historyAfterRetry = try await setup.e1rm.fetchHistory(
    studentId: setup.fixture.studentID,
    exerciseId: setup.fixture.exercise.id
  )
  expectSuccessfulRetry(
    result: retried,
    history: historyAfterRetry,
    originalLogID: setup.originalLog.id,
    newLogID: setup.newLog.id
  )
}

private struct InterleavingSetup {
  let fixture: CoachRPEFixture
  let originalLog: StudentSetLog
  let newLog: StudentSetLog
  let e1rm: ReconciliationSpyE1RMRepository
  let reconciler: E1RMCoachRPEReconciler
}

private struct AbandonedReplacementSnapshot {
  let result: E1RMCoachRPEReconciler.Result
  let history: [E1RMHistoryPoint]
  let baseline: E1RMWeightBaseline
  let prEvents: [PRBreakthroughEvent]
  let originalLogID: UUID
  let newLogID: UUID
  let successfulReplaceCount: Int
}

private func makeInterleavingSetup() async throws -> InterleavingSetup {
  let fixture = makeCoachRPEFixture()
  let originalLog = coachRPELog(
    fixture: fixture,
    weightKg: 140,
    rpe: 6,
    date: fixture.anchor
  )
  let logs = InMemoryStudentTrainingLogRepository(seed: [originalLog])
  let e1rm = ReconciliationSpyE1RMRepository()
  await recordCoachRPEPoint(log: originalLog, fixture: fixture, in: e1rm)
  _ = try await logs.recordSet(replacingCoachRPE(in: originalLog, with: 8))
  let newLog = coachRPELog(
    fixture: fixture,
    setIndex: 1,
    weightKg: 150,
    rpe: 8,
    date: fixture.anchor.addingTimeInterval(60)
  )
  await e1rm.runBeforeNextConditionalReplace {
    _ = try? await logs.recordSet(newLog)
    await recordCoachRPEPoint(log: newLog, fixture: fixture, in: e1rm)
  }
  return InterleavingSetup(
    fixture: fixture,
    originalLog: originalLog,
    newLog: newLog,
    e1rm: e1rm,
    reconciler: makeCoachRPEReconciler(fixture: fixture, logs: logs, e1rm: e1rm)
  )
}

private func expectAbandonedReplacement(_ snapshot: AbandonedReplacementSnapshot) {
  #expect(snapshot.result == .init(didReconcile: false, pointCount: 0))
  #expect(snapshot.history.map(\.setLogId).contains(snapshot.newLogID))
  #expect(
    snapshot.history.first(where: { $0.setLogId == snapshot.originalLogID })?.sourceCoachRPE
      == nil
  )
  #expect(snapshot.baseline.setLogId == snapshot.newLogID)
  #expect(snapshot.baseline.maxWeightKg == 150)
  #expect(snapshot.prEvents.contains(where: { $0.breakthroughWeightKg == 150 }))
  #expect(snapshot.successfulReplaceCount == 0)
}

private func expectSuccessfulRetry(
  result: E1RMCoachRPEReconciler.Result,
  history: [E1RMHistoryPoint],
  originalLogID: UUID,
  newLogID: UUID
) {
  #expect(result.didReconcile)
  #expect(history.map(\.setLogId).contains(newLogID))
  #expect(history.first(where: { $0.setLogId == originalLogID })?.sourceCoachRPE == 8)
}

@MainActor
@Test func reconciliationFailureLeavesLoadedWorkoutStateIntact() async throws {
  let fixture = makeCoachRPEFixture()
  let viewModel = TodayWorkoutViewModel(
    plans: fixture.plans,
    logs: InMemoryStudentTrainingLogRepository()
  )
  await viewModel.load(date: fixture.anchor, studentID: fixture.studentID)
  let loadedState = viewModel.state
  let reconciler = makeCoachRPEReconciler(
    fixture: fixture,
    logs: ThrowingFetchTrainingLogRepository(),
    e1rm: InMemoryE1RMRepository()
  )

  let result = await viewModel.reconcileCoachRPE(
    using: reconciler,
    studentID: fixture.studentID
  )

  #expect(result == nil)
  #expect(viewModel.state == loadedState)
}

private actor ThrowingFetchTrainingLogRepository: StudentTrainingLogRepository {
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    throw TestError()
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}
