import CoreModels
import Foundation
import Testing

@testable import StudentKit

// Spec 050 §3: the shared recorder — eligibility gate up front, PR only past
// the noise band.

private let student = UUID()
private let squat = UUID()

@available(iOS 17.0, macOS 14.0, *)
private func makeRecorder(seed: [E1RMHistoryPoint] = []) -> (E1RMRecorder, InMemoryE1RMRepository) {
  let repo = InMemoryE1RMRepository(seedPoints: seed)
  return (E1RMRecorder(e1rm: repo, now: { Date(timeIntervalSince1970: 1_782_000_000) }), repo)
}

private func seededPoint(e1RM: Double) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: student,
    exerciseId: squat,
    setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_781_000_000),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.85,
    sourceReps: 5,
    sourceRPE: 8
  )
}

@available(iOS 17.0, macOS 14.0, *)
@Test func wobbleInsideNoiseBandIsNotAPR() async throws {
  // Best 200 → band = max(0.5, 6) = 6 kg. A +2% (204) estimate stays quiet.
  let (recorder, repo) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  // E1RMCalculator (RTS 扩展表): 5reps@RPE8 ≈ 78% → 158 kg ≈ 202.6 e1RM —
  // clears the 200 best but stays inside the 206 band edge.
  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 158, reps: 5, rpe: 8, failed: false))

  #expect(event == nil)
  // The point itself still records (history is honest; only the PR is gated).
  let history = try await repo.fetchHistory(studentId: student, exerciseIds: [squat])
  #expect((history[squat] ?? []).count == 2)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func clearingTheNoiseBandFiresAPR() async {
  let (recorder, _) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  // A clean +6% PR (165kg×5@8 ≈ 211 e1RM) clears the 206 band and fires. §5
  // leaves sub-anomaly PRs alone; a 190×5@9 (~232, +16%) would now be quarantined.
  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 165, reps: 5, rpe: 8, failed: false))

  #expect(event != nil)
  #expect((event?.previousMaxE1RMKg ?? 0) == 200)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func ineligibleSetsProduceNoPointAndNoPR() async throws {
  let (recorder, repo) = makeRecorder()

  let lowRPE = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 100, reps: 5, rpe: 6, failed: false))
  let highRepDeadlift = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .deadlift, setLogID: UUID(),
      weightKg: 180, reps: 8, rpe: 9, failed: false))
  let failedSet = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 200, reps: 1, rpe: 10, failed: true))

  #expect(lowRPE == nil)
  #expect(highRepDeadlift == nil)
  #expect(failedSet == nil)
  let history = try await repo.fetchHistory(studentId: student, exerciseIds: [squat])
  #expect((history[squat] ?? []).isEmpty)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func firstEverEligibleSetIsAPR() async {
  let (recorder, _) = makeRecorder()

  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 100, reps: 5, rpe: 8, failed: false))

  #expect(event != nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func importedNormalPointSetsPRBaselineButIsNeverItselfCelebrated() async {
  let importedBest = E1RMHistoryPoint(
    id: UUID(), studentId: student, exerciseId: squat, setLogId: UUID(),
    computedAt: Date(timeIntervalSince1970: 1_781_000_000), e1RMKg: 165,
    sourceWeightKg: 140, sourceReps: 5, sourceRPE: 8, origin: .imported)
  let (recorder, repo) = makeRecorder(seed: [importedBest])

  let belowBaseline = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 135, reps: 5, rpe: nil, failed: false))
  let realBreakthrough = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 150, reps: 5, rpe: nil, failed: false))

  #expect(belowBaseline == nil)
  #expect(realBreakthrough?.previousMaxE1RMKg == 165)
  let events = try? await repo.unacknowledgedPRs(studentId: student)
  #expect(events?.count == 1)
}

// Spec 050 §5: graded anomaly guard.

@available(iOS 17.0, macOS 14.0, *)
@Test func suspectSpikeIsQuarantinedNotCelebrated() async throws {
  // Best 200; a 275kg×3@8.5 fat-finger (should be 175) estimates ~320 e1RM (+60%).
  let (recorder, repo) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 275, reps: 3, rpe: 8.5, failed: false))

  #expect(event == nil)  // no fake PR celebration
  let history = try await repo.fetchHistory(studentId: student, exerciseId: squat)
  let recorded = try #require(history.last)
  #expect(recorded.confidence == .low)  // quarantined, kept for honest scatter
}

@available(iOS 17.0, macOS 14.0, *)
@Test func softAnomalyIsLowConfidenceAndNoPR() async throws {
  // Best 200; +12% (175kg×5@8 ≈ 224 e1RM) is unusual for one session → downweight.
  let (recorder, repo) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 175, reps: 5, rpe: 8, failed: false))

  #expect(event == nil)
  let history = try await repo.fetchHistory(studentId: student, exerciseId: squat)
  #expect(try #require(history.last).confidence == .low)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func quarantinedSpikeDoesNotPoisonThePRBaseline() async {
  // The core P0-5 fix: a quarantined +60% spike must not freeze the PR system.
  // A later legit +5% PR still fires against the real 200, not the phantom 320.
  let (recorder, _) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  _ = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 275, reps: 3, rpe: 8.5, failed: false))
  let realPR = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
      weightKg: 164, reps: 5, rpe: 8, failed: false))

  #expect(realPR != nil)
  #expect((realPR?.previousMaxE1RMKg ?? 0) == 200)  // baseline used 200, not 320
}

@available(iOS 17.0, macOS 14.0, *)
@Test func realLogReplacingImportedPointIsNotGatedByItsOwnStaleValue() async throws {
  // Imported history claims 200 for this very set; the athlete actually hits
  // 133x5@8 ≈ 170.5 e1RM. The stale imported 200 must not be the bar
  // (spec 053 §3): the baseline falls back to the other trusted point (160),
  // 170.5 clears 160 + 4.8 band → PR, and the point is replaced in place.
  let sharedSetLogID = UUID()
  let imported = E1RMHistoryPoint(
    id: UUID(), studentId: student, exerciseId: squat, setLogId: sharedSetLogID,
    computedAt: Date(timeIntervalSince1970: 1_781_000_000), e1RMKg: 200,
    sourceWeightKg: 170, sourceReps: 5, sourceRPE: nil,
    confidence: .normal, origin: .imported)
  let (recorder, repo) = makeRecorder(seed: [seededPoint(e1RM: 160), imported])

  let event = await recorder.record(
    E1RMRecorder.Input(
      studentID: student, exerciseID: squat, family: .squat, setLogID: sharedSetLogID,
      weightKg: 133, reps: 5, rpe: 8, failed: false))

  let points = try await repo.fetchHistory(studentId: student, exerciseId: squat)
  let replaced = points.filter { $0.setLogId == sharedSetLogID }
  #expect(replaced.count == 1)
  #expect(replaced.first?.origin == .logged)
  #expect(replaced.first?.e1RMKg ?? 0 < 180)
  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == 160)
}
