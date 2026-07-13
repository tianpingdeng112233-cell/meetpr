import CoreModels
import Foundation
import Testing

@testable import StudentKit

private let recorderStudentID = UUID()
private let recorderExerciseID = UUID()
private let recorderNow = Date(timeIntervalSince1970: 1_782_000_000)

private func makeRecorder(
  seed: [E1RMHistoryPoint] = []
) -> (E1RMRecorder, InMemoryE1RMRepository) {
  let repository = InMemoryE1RMRepository(seedPoints: seed)
  let recorder = E1RMRecorder(e1rm: repository, now: { recorderNow })
  return (recorder, repository)
}

private func recorderPoint(
  e1RM: Double,
  reps: Int = 1,
  rpe: Double? = 10,
  confidence: E1RMConfidence = .normal
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID,
    setLogId: UUID(),
    computedAt: recorderNow.addingTimeInterval(-86_400),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM,
    sourceReps: reps,
    sourceRPE: rpe,
    confidence: confidence
  )
}

private func recorderInput(
  weightKg: Decimal,
  reps: Int = 1,
  rpe: Decimal? = 10,
  family: LiftFamily = .squat,
  completed: Bool = true,
  failed: Bool = false,
  priorConfidence: E1RMConfidence? = nil
) -> E1RMRecorder.Input {
  E1RMRecorder.Input(
    studentID: recorderStudentID,
    exerciseID: recorderExerciseID,
    family: family,
    setLogID: UUID(),
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    completed: completed,
    failed: failed,
    priorConfidence: priorConfidence
  )
}

@Test func twoPercentImprovementInsideNoiseBandDoesNotFirePR() async throws {
  let (recorder, repository) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  let event = await recorder.record(recorderInput(weightKg: 204))

  #expect(event == nil)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
}

@Test func fourPercentImprovementOutsideNoiseBandFiresPR() async {
  let (recorder, _) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  let event = await recorder.record(recorderInput(weightKg: 208))

  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == 200)
  #expect(event?.breakthroughE1RMKg == 208)
}

@Test func ineligibleSetsProduceNeitherPointNorPR() async throws {
  let (recorder, repository) = makeRecorder()

  let incomplete = await recorder.record(
    recorderInput(weightKg: 100, completed: false)
  )
  let failed = await recorder.record(
    recorderInput(weightKg: 100, failed: true)
  )
  let lowRPE = await recorder.record(
    recorderInput(weightKg: 100, reps: 5, rpe: 6)
  )
  let highRepDeadlift = await recorder.record(
    recorderInput(weightKg: 100, reps: 6, rpe: 9, family: .deadlift)
  )

  #expect(incomplete == nil)
  #expect(failed == nil)
  #expect(lowRPE == nil)
  #expect(highRepDeadlift == nil)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.isEmpty)
}

@Test func legacyIneligibleSpikeDoesNotRaisePRBaseline() async {
  let spike = recorderPoint(e1RM: 300, reps: 12, rpe: 10)
  let (recorder, _) = makeRecorder(seed: [spike])

  let event = await recorder.record(recorderInput(weightKg: 100))

  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == 0)
}

@Test func normalImprovementBelowAnomalyThresholdStillFiresPR() async {
  let (recorder, _) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  let event = await recorder.record(recorderInput(weightKg: 216))

  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == 200)
  #expect(event?.breakthroughE1RMKg == 216)
}

@Test func suspectSpikeIsPersistedAsLowConfidenceWithoutPR() async throws {
  let (recorder, repository) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  let event = await recorder.record(recorderInput(weightKg: 350))

  #expect(event == nil)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
  #expect(history.last?.e1RMKg == 350)
  #expect(history.last?.confidence == .low)
}

@Test func priorNormalConfidenceDoesNotOverrideReplayAnomalyVerdict() async throws {
  let (recorder, repository) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  let event = await recorder.record(
    recorderInput(weightKg: 225, priorConfidence: .normal)
  )

  #expect(event == nil)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
  #expect(history.last?.e1RMKg == 225)
  #expect(history.last?.confidence == .low)
}

@Test func quarantinedSpikeDoesNotPoisonNextPRBaseline() async {
  let (recorder, _) = makeRecorder(seed: [recorderPoint(e1RM: 200)])

  _ = await recorder.record(recorderInput(weightKg: 350))
  let realPR = await recorder.record(recorderInput(weightKg: 208))

  #expect(realPR != nil)
  #expect(realPR?.previousMaxE1RMKg == 200)
}

@Test func anomalyThresholdsMatchSpec050() {
  #expect(E1RMPolicy.softJump == 0.10)
  #expect(E1RMPolicy.hardJump == 0.18)
}
