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
    studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
    weightKg: 158, reps: 5, rpe: 8, failed: false)

  #expect(event == nil)
  // The point itself still records (history is honest; only the PR is gated).
  let history = try await repo.fetchHistory(studentId: student, exerciseIds: [squat])
  #expect((history[squat] ?? []).count == 2)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func clearingTheNoiseBandFiresAPR() async {
  let (recorder, _) = makeRecorder(seed: [seededPoint(e1RM: 200)])

  // A big jump (well past 206) fires.
  let event = await recorder.record(
    studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
    weightKg: 190, reps: 5, rpe: 9, failed: false)

  #expect(event != nil)
  #expect((event?.previousMaxE1RMKg ?? 0) == 200)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func ineligibleSetsProduceNoPointAndNoPR() async throws {
  let (recorder, repo) = makeRecorder()

  let lowRPE = await recorder.record(
    studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
    weightKg: 100, reps: 5, rpe: 6, failed: false)
  let highRepDeadlift = await recorder.record(
    studentID: student, exerciseID: squat, family: .deadlift, setLogID: UUID(),
    weightKg: 180, reps: 8, rpe: 9, failed: false)
  let failedSet = await recorder.record(
    studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
    weightKg: 200, reps: 1, rpe: 10, failed: true)

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
    studentID: student, exerciseID: squat, family: .squat, setLogID: UUID(),
    weightKg: 100, reps: 5, rpe: 8, failed: false)

  #expect(event != nil)
}
