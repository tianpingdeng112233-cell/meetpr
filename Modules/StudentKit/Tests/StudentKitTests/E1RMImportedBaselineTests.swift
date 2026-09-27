import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func firstLiveDeadliftEstablishesItsOwnAnomalyBaselineAfterImport() async throws {
  let studentID = UUID()
  let exerciseID = UUID()
  let date = Date(timeIntervalSince1970: 1_785_000_000)
  let imported = E1RMHistoryPoint(
    id: UUID(), studentId: studentID, exerciseId: exerciseID, family: .deadlift,
    setLogId: UUID(), computedAt: date.addingTimeInterval(-86_400),
    e1RMKg: 151.6666666667, sourceWeightKg: 130, sourceReps: 5,
    sourceRPE: nil, confidence: .normal, origin: .imported
  )
  let repository = InMemoryE1RMRepository(seedPoints: [imported])
  let recorder = E1RMRecorder(e1rm: repository, now: { date })
  _ = await recorder.record(
    .init(
      studentID: studentID, exerciseID: exerciseID, family: .deadlift,
      setLogID: UUID(), weightKg: 135, reps: 5, rpe: 6,
      completed: true, failed: false, registeredOneRMKg: 210
    )
  )

  let history = try await repository.fetchHistory(studentId: studentID, family: .deadlift)
  let live = try #require(history.first { $0.origin == .logged })
  #expect(live.confidence == .normal)
  #expect(abs(live.e1RMKg - 192.8571428571) < 0.001)
  #expect(history.contains(imported))
}

@MainActor
@Test func importedBaselineUpgradeRestoresRealHistoryAndIsIdempotent() async throws {
  let fixture = try ImportedBaselineFixture()
  let e1rm = ReconciliationSpyE1RMRepository(
    backing: InMemoryE1RMRepository(seedPoints: fixture.oldPoints)
  )
  let viewModel = GrowthCurveViewModel(plans: fixture.plans, e1rm: e1rm, now: { fixture.now })
  await viewModel.load(studentID: fixture.studentID)
  let before = GrowthScreenPresentation.snapshot(
    from: viewModel, family: .deadlift, range: .ninetyDays, now: fixture.now
  )
  #expect(abs((before.currentKg ?? 0) - 151.6666666667) < 0.001)
  #expect(before.cardState == .formingWindowSparse)

  let reconciler = fixture.reconciler(e1rm: e1rm)
  let result = try await reconciler.reconcile(studentID: fixture.studentID)
  #expect(result.didReconcile)
  let history = try await e1rm.fetchHistory(studentId: fixture.studentID, family: .deadlift)
  #expect(history.filter { $0.origin == .logged && $0.confidence == .normal }.count == 31)
  #expect(Set(history.map(\.id)) == Set(fixture.oldPoints.map(\.id)))
  #expect(
    history.filter { $0.origin == .imported } == fixture.oldPoints.filter { $0.origin == .imported }
  )
  #expect(try await e1rm.fetchPRs(studentId: fixture.studentID, family: .deadlift).isEmpty)

  await viewModel.load(studentID: fixture.studentID)
  let after = GrowthScreenPresentation.snapshot(
    from: viewModel, family: .deadlift, range: .ninetyDays, now: fixture.now
  )
  #expect(after.cardState == .chart)
  #expect(after.samples.count == 8)
  #expect(abs((after.currentKg ?? 0) - 221.4285714286) < 0.001)
  let mutations = await e1rm.mutationCallCount
  #expect(try await reconciler.reconcile(studentID: fixture.studentID).didReconcile == false)
  #expect(await e1rm.mutationCallCount == mutations)
}

@Test(arguments: [E1RMConfidence.normal, .low])
func reviewedImportsCannotMaskALiveAnomaly(confidence: E1RMConfidence) async throws {
  let fixture = try ImportedBaselineFixture()
  let imported = E1RMHistoryPoint(
    id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID, family: .deadlift,
    setLogId: UUID(), computedAt: fixture.now.addingTimeInterval(-86_400),
    e1RMKg: 500, sourceWeightKg: 400, sourceReps: 5, sourceRPE: nil,
    confidence: confidence, origin: .imported
  )
  let e1rm = InMemoryE1RMRepository(seedPoints: [imported])
  for (index, weight) in [135, 200].enumerated() {
    let date = fixture.now.addingTimeInterval(Double(index))
    _ = await E1RMRecorder(e1rm: e1rm, now: { date }).record(
      .init(
        studentID: fixture.studentID, exerciseID: fixture.exerciseID, family: .deadlift,
        setLogID: UUID(), weightKg: Decimal(weight), reps: 5, rpe: 6,
        completed: true, failed: false
      ))
  }
  let history = try await e1rm.fetchHistory(studentId: fixture.studentID, family: .deadlift)
  #expect(history.contains(imported))
  #expect(history.filter { $0.origin == .logged }.map(\.confidence) == [.normal, .low])
}

@Test(arguments: [false, true])
func importedBaselineRepairPreservesRetiredFamilyReviewAndPR(missingPoint: Bool) async throws {
  let fixture = try ImportedBaselineFixture()
  let retired = E1RMHistoryPoint(
    id: UUID(), studentId: fixture.studentID, exerciseId: UUID(), family: .bench,
    setLogId: UUID(), computedAt: fixture.now, e1RMKg: 100, sourceWeightKg: 90,
    sourceReps: 3, sourceRPE: 9, confidence: .low, origin: .logged
  )
  let reviewed = E1RMHistoryPoint(
    id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID, family: .deadlift,
    setLogId: UUID(), computedAt: fixture.now, e1RMKg: 500, sourceWeightKg: 400,
    sourceReps: 5, sourceRPE: nil, confidence: .low, origin: .imported
  )
  let event = PRBreakthroughEvent(
    id: UUID(), studentId: fixture.studentID, exerciseId: fixture.exerciseID, family: .deadlift,
    pointId: fixture.oldPoints.last?.id, breakthroughE1RMKg: 220, previousMaxE1RMKg: 210,
    breakthroughWeightKg: 160, previousMaxWeightKg: 155, occurredAt: fixture.now,
    acknowledgedAt: fixture.now
  )
  let e1rm = InMemoryE1RMRepository(
    seedPoints: (missingPoint ? Array(fixture.oldPoints.dropLast()) : fixture.oldPoints)
      + [retired, reviewed], seedPRs: [event]
  )
  #expect(
    try await fixture.reconciler(e1rm: e1rm).reconcile(studentID: fixture.studentID).didReconcile)
  #expect(try await e1rm.fetchHistory(studentId: fixture.studentID, family: .bench) == [retired])
  #expect(
    try await e1rm.fetchHistory(studentId: fixture.studentID, family: .deadlift).contains(reviewed))
  #expect(try await e1rm.fetchPRs(studentId: fixture.studentID, family: .deadlift) == [event])
}

@Test func importedBaselineRepairRetriesAfterConcurrentReviewWithoutOverwritingIt() async throws {
  let fixture = try ImportedBaselineFixture()
  let e1rm = ReconciliationSpyE1RMRepository(
    backing: InMemoryE1RMRepository(seedPoints: fixture.oldPoints)
  )
  let importedID = try #require(fixture.oldPoints.first?.id)
  await e1rm.runBeforeNextConditionalReplace {
    try? await e1rm.updatePointConfidence(
      studentId: fixture.studentID, pointIDs: [importedID], confidence: .low
    )
  }
  let reconciler = fixture.reconciler(e1rm: e1rm)
  #expect(try await reconciler.reconcile(studentID: fixture.studentID).didReconcile == false)
  #expect(await e1rm.successfulConditionalReplaceCount == 0)
  #expect(try await reconciler.reconcile(studentID: fixture.studentID).didReconcile)
  let history = try await e1rm.fetchHistory(studentId: fixture.studentID, family: .deadlift)
  #expect(history.first(where: { $0.id == importedID })?.confidence == .low)
  #expect(history.filter { $0.origin == .logged && $0.confidence == .normal }.count == 31)
}

@MainActor
@Test func importedBaselineRepairSurvivesReopeningTheLocalStore() async throws {
  let fixture = try ImportedBaselineFixture()
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let oldStore = LocalE1RMRepository(directory: directory)
  try await oldStore.replaceHistory(
    studentId: fixture.studentID, with: fixture.oldPoints, weightBaselines: [], prEvents: []
  )
  let upgradedStore = LocalE1RMRepository(directory: directory)
  let firstScreen = GrowthCurveViewModel(
    plans: fixture.plans, e1rm: upgradedStore,
    onboarding: InMemoryOnboardingRepository(studentId: fixture.studentID, seed: fixture.profile),
    logs: InMemoryStudentTrainingLogRepository(seed: fixture.logs), now: { fixture.now }
  )
  await firstScreen.load(studentID: fixture.studentID)
  let reopened = LocalE1RMRepository(directory: directory)
  let viewModel = GrowthCurveViewModel(plans: fixture.plans, e1rm: reopened, now: { fixture.now })
  await viewModel.load(studentID: fixture.studentID)
  let snapshot = GrowthScreenPresentation.snapshot(
    from: viewModel, family: .deadlift, range: .ninetyDays, now: fixture.now
  )
  #expect(snapshot.cardState == .chart)
  #expect(abs((snapshot.currentKg ?? 0) - 221.4285714286) < 0.001)
  #expect(
    try await fixture.reconciler(e1rm: reopened)
      .reconcile(studentID: fixture.studentID).didReconcile == false)
}

@Test func importedBaselineRepairRetriesAfterDiskWriteFailure() async throws {
  let fixture = try ImportedBaselineFixture()
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let e1rm = LocalE1RMRepository(directory: directory)
  try await e1rm.replaceHistory(
    studentId: fixture.studentID, with: fixture.oldPoints, weightBaselines: [], prEvents: []
  )
  // The repository has loaded the old state. Replace only this test directory
  // with a file to simulate an atomic persistence failure after replay.
  try FileManager.default.removeItem(at: directory)
  try Data().write(to: directory)
  let reconciler = fixture.reconciler(e1rm: e1rm)
  await #expect(throws: (any Error).self) {
    try await reconciler.reconcile(studentID: fixture.studentID)
  }
  let unchanged = try await e1rm.fetchHistory(studentId: fixture.studentID, family: .deadlift)
  #expect(unchanged == fixture.oldPoints)
  try FileManager.default.removeItem(at: directory)
  #expect(try await reconciler.reconcile(studentID: fixture.studentID).didReconcile)
  let reopened = LocalE1RMRepository(directory: directory)
  let recovered = try await reopened.fetchHistory(studentId: fixture.studentID, family: .deadlift)
  #expect(recovered.filter { $0.origin == .logged && $0.confidence == .normal }.count == 31)
}

@Test func importedBaselineRepairCannotRegressANewerWeightBaseline() async throws {
  let fixture = try ImportedBaselineFixture()
  let e1rm = InMemoryE1RMRepository(seedPoints: fixture.oldPoints)
  let baseline = E1RMWeightBaseline(
    studentId: fixture.studentID, family: .deadlift, maxWeightKg: 230,
    setLogId: UUID(), achievedAt: fixture.now, previousMaxWeightKg: 225
  )
  _ = try await e1rm.recordWeightBaseline(baseline)
  #expect(
    try await fixture.reconciler(e1rm: e1rm).reconcile(studentID: fixture.studentID).didReconcile)
  #expect(
    try await e1rm.fetchWeightBaseline(studentId: fixture.studentID, family: .deadlift) == baseline)
}
