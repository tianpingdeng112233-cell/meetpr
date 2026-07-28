import CoreModels
import Foundation
import Testing

@testable import StudentKit

private let recorderStudentID = UUID()
private let recorderExerciseID = UUID()
private let recorderNow = Date(timeIntervalSince1970: 1_782_000_000)

private func makeRecorder(
  seed: [E1RMHistoryPoint] = [],
  baselineWeightKg: Double? = nil,
  baselineFamily: LiftFamily = .squat
) -> (E1RMRecorder, InMemoryE1RMRepository) {
  let baselines =
    baselineWeightKg.map {
      [
        E1RMWeightBaseline(
          studentId: recorderStudentID,
          family: baselineFamily,
          maxWeightKg: $0,
          setLogId: UUID(),
          achievedAt: recorderNow.addingTimeInterval(-86_400)
        )
      ]
    } ?? []
  let repository = InMemoryE1RMRepository(
    seedPoints: seed,
    seedWeightBaselines: baselines
  )
  let recorder = E1RMRecorder(e1rm: repository, now: { recorderNow })
  return (recorder, repository)
}

private func recorderPoint(
  e1RM: Double,
  reps: Int = 1,
  rpe: Double? = 10,
  confidence: E1RMConfidence = .normal,
  setLogID: UUID = UUID(),
  origin: E1RMPointOrigin = .logged,
  sourceWeightKg: Double? = nil,
  exerciseID: UUID = recorderExerciseID,
  family: LiftFamily? = .squat
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: recorderStudentID,
    exerciseId: exerciseID,
    family: family,
    setLogId: setLogID,
    computedAt: recorderNow.addingTimeInterval(-86_400),
    e1RMKg: e1RM,
    sourceWeightKg: sourceWeightKg ?? e1RM,
    sourceReps: reps,
    sourceRPE: rpe,
    confidence: confidence,
    origin: origin
  )
}

private func recorderInput(
  weightKg: Decimal,
  reps: Int = 1,
  rpe: Decimal? = 10,
  coachRPE: Decimal? = nil,
  family: LiftFamily? = .squat,
  completed: Bool = true,
  failed: Bool = false,
  registeredOneRMKg: Decimal? = nil,
  confidenceOverride: E1RMConfidence? = nil,
  setLogID: UUID = UUID()
) -> E1RMRecorder.Input {
  E1RMRecorder.Input(
    studentID: recorderStudentID,
    exerciseID: recorderExerciseID,
    family: family,
    setLogID: setLogID,
    weightKg: weightKg,
    reps: reps,
    rpe: rpe,
    coachRPE: coachRPE,
    completed: completed,
    failed: failed,
    registeredOneRMKg: registeredOneRMKg,
    confidenceOverride: confidenceOverride
  )
}

@Test func anyStrictMeasuredWeightImprovementFiresPR() async throws {
  let (recorder, repository) = makeRecorder(
    seed: [recorderPoint(e1RM: 200)],
    baselineWeightKg: 200
  )

  let event = await recorder.record(recorderInput(weightKg: 204))

  #expect(event?.breakthroughWeightKg == 204)
  #expect(event?.previousMaxWeightKg == 200)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
}

@Test func e1RMImprovementWithoutMeasuredWeightImprovementDoesNotFirePR() async {
  let prior = recorderPoint(e1RM: 190, sourceWeightKg: 200)
  let (recorder, _) = makeRecorder(seed: [prior], baselineWeightKg: 200)

  let event = await recorder.record(
    recorderInput(weightKg: 200, reps: 1, rpe: 10)
  )

  #expect(event == nil)
}

@Test func incompleteAndFailedSetsProduceNeitherPointNorPR() async throws {
  let (recorder, repository) = makeRecorder()

  let incomplete = await recorder.record(
    recorderInput(weightKg: 100, completed: false)
  )
  let failed = await recorder.record(
    recorderInput(weightKg: 100, failed: true)
  )
  #expect(incomplete == nil)
  #expect(failed == nil)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.isEmpty)
}

@Test func ineligibleE1RMSetStillProducesMeasuredWeightPRWithoutPoint() async throws {
  let (recorder, repository) = makeRecorder()

  let highRepDeadlift = await recorder.record(
    recorderInput(weightKg: 220, reps: 6, rpe: 9, family: .deadlift)
  )
  let invalidRPE = await recorder.record(
    recorderInput(weightKg: 225, reps: 5, rpe: 10.5, family: .deadlift)
  )
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    family: .deadlift
  )

  #expect(highRepDeadlift?.breakthroughWeightKg == 220)
  #expect(highRepDeadlift?.previousMaxWeightKg == 0)
  #expect(highRepDeadlift?.pointId == nil)
  #expect(highRepDeadlift?.breakthroughE1RMKg == nil)
  #expect(invalidRPE?.breakthroughWeightKg == 225)
  #expect(invalidRPE?.previousMaxWeightKg == 220)
  #expect(invalidRPE?.pointId == nil)
  #expect(history.isEmpty)
}

@Test func unresolvedCompetitionFamilyProducesNeitherPointNorPR() async throws {
  let (recorder, repository) = makeRecorder()

  let event = await recorder.record(
    recorderInput(weightKg: 220, family: nil)
  )

  #expect(event == nil)
  #expect(
    try await repository.fetchHistory(
      studentId: recorderStudentID,
      exerciseId: recorderExerciseID
    ).isEmpty
  )
}

@Test func lowRPEUsesEpleyAndCoachCalibrationOverridesIt() async throws {
  let (recorder, repository) = makeRecorder()

  _ = await recorder.record(
    recorderInput(weightKg: 140, reps: 5, rpe: 6, registeredOneRMKg: 210)
  )
  _ = await recorder.record(
    recorderInput(
      weightKg: 140,
      reps: 5,
      rpe: 6,
      coachRPE: 8,
      registeredOneRMKg: 210,
      setLogID: UUID()
    )
  )

  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
  #expect(history[0].e1RMKg == E1RMCalculator.calculate(weightKg: 140, reps: 5, rpe: 6))
  #expect(history[1].e1RMKg == E1RMCalculator.calculate(weightKg: 140, reps: 5, rpe: 8))
  #expect(history[1].sourceRPE == 6)
  #expect(history[1].sourceCoachRPE == 8)
}

@Test func registeredOneRMAndMeasuredHistoryDriveRollingPRBaseline() async {
  let (recorder, _) = makeRecorder()

  let belowRegistration = await recorder.record(
    recorderInput(weightKg: 150, registeredOneRMKg: 210)
  )
  let firstPR = await recorder.record(
    recorderInput(weightKg: 212.5, registeredOneRMKg: 210)
  )
  let equal = await recorder.record(
    recorderInput(weightKg: 212.5, registeredOneRMKg: 210)
  )
  let rolledPR = await recorder.record(
    recorderInput(weightKg: 215, registeredOneRMKg: 210)
  )

  #expect(belowRegistration == nil)
  #expect(firstPR?.breakthroughWeightKg == 212.5)
  #expect(firstPR?.previousMaxWeightKg == 210)
  #expect(equal == nil)
  #expect(rolledPR?.breakthroughWeightKg == 215)
  #expect(rolledPR?.previousMaxWeightKg == 212.5)
}

@Test func competitionFamilyExercisesShareMeasuredWeightBaseline() async {
  let stanceSpecificExerciseID = UUID()
  let familyRecord = recorderPoint(
    e1RM: 230,
    sourceWeightKg: 220,
    exerciseID: stanceSpecificExerciseID
  )
  let (recorder, _) = makeRecorder(seed: [familyRecord], baselineWeightKg: 220)

  let belowFamilyRecord = await recorder.record(
    recorderInput(
      weightKg: 212.5,
      registeredOneRMKg: 210
    )
  )
  let aboveFamilyRecord = await recorder.record(
    recorderInput(
      weightKg: 222.5,
      registeredOneRMKg: 210
    )
  )

  #expect(belowFamilyRecord == nil)
  #expect(aboveFamilyRecord?.previousMaxWeightKg == 220)
  #expect(aboveFamilyRecord?.breakthroughWeightKg == 222.5)
}

@Test func legacyIneligibleSpikeDoesNotRaisePRBaseline() async {
  let spike = recorderPoint(e1RM: 300, reps: 12, rpe: 10)
  let (recorder, _) = makeRecorder(seed: [spike])

  let event = await recorder.record(recorderInput(weightKg: 100))

  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == nil)
}

@Test func normalImprovementBelowAnomalyThresholdStillFiresPR() async {
  let (recorder, _) = makeRecorder(
    seed: [recorderPoint(e1RM: 200)],
    baselineWeightKg: 200
  )

  let event = await recorder.record(recorderInput(weightKg: 216))

  #expect(event != nil)
  #expect(event?.previousMaxE1RMKg == 200)
  #expect(event?.breakthroughE1RMKg == 216)
}

@Test func suspectE1RMSpikeStaysLowConfidenceButMeasuredWeightStillSetsPR() async throws {
  let (recorder, repository) = makeRecorder(
    seed: [recorderPoint(e1RM: 200)],
    baselineWeightKg: 200
  )

  let event = await recorder.record(recorderInput(weightKg: 350))

  #expect(event?.breakthroughWeightKg == 350)
  #expect(event?.previousMaxWeightKg == 200)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
  #expect(history.last?.e1RMKg == 350)
  #expect(history.last?.confidence == .low)
}

@Test func replayConfidenceOverrideBypassesAnomalyVerdict() async throws {
  let (recorder, repository) = makeRecorder(
    seed: [recorderPoint(e1RM: 200)],
    baselineWeightKg: 200
  )

  let event = await recorder.record(
    recorderInput(weightKg: 225, confidenceOverride: .normal)
  )

  #expect(event?.breakthroughWeightKg == 225)
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  #expect(history.count == 2)
  #expect(history.last?.family == .squat)
  #expect(history.last?.e1RMKg == 225)
  #expect(history.last?.confidence == .normal)
}

@Test func quarantinedE1RMStaysOutOfEstimateBaselineButWeightBaselineRolls() async throws {
  let (recorder, repository) = makeRecorder(
    seed: [recorderPoint(e1RM: 200)],
    baselineWeightKg: 200
  )

  _ = await recorder.record(recorderInput(weightKg: 350))
  let event = await recorder.record(recorderInput(weightKg: 208))
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )

  #expect(event == nil)
  #expect(history.last?.confidence == .normal)
  #expect(history.last?.e1RMKg == 208)
}

@Test func importedPointDoesNotSubstituteForPersistentWeightBaseline() async throws {
  let imported = recorderPoint(e1RM: 165, origin: .imported)
  let (recorder, repository) = makeRecorder(seed: [imported])

  let firstMeasuredRecord = await recorder.record(recorderInput(weightKg: 160))
  let above = await recorder.record(recorderInput(weightKg: 172))

  #expect(firstMeasuredRecord?.breakthroughWeightKg == 160)
  #expect(firstMeasuredRecord?.previousMaxWeightKg == 0)
  #expect(above != nil)
  #expect(above?.previousMaxE1RMKg == 165)
  let events = try await repository.unacknowledgedPRs(studentId: recorderStudentID)
  #expect(events.count == 2)
  #expect(events.contains { $0.id == above?.id && $0.pointId == above?.pointId })
}

@Test func realLogReplacesImportedIdentityWithoutStaleValueGatingIt() async throws {
  let sharedSetLogID = UUID()
  let baseline = recorderPoint(e1RM: 160)
  let imported = recorderPoint(
    e1RM: 200,
    setLogID: sharedSetLogID,
    origin: .imported
  )
  let (recorder, repository) = makeRecorder(seed: [baseline, imported])

  let event = await recorder.record(
    recorderInput(weightKg: 172, setLogID: sharedSetLogID)
  )
  let history = try await repository.fetchHistory(
    studentId: recorderStudentID,
    exerciseId: recorderExerciseID
  )
  let replacement = history.filter { $0.setLogId == sharedSetLogID }

  #expect(history.count == 2)
  #expect(replacement.count == 1)
  #expect(replacement.first?.id == imported.id)
  #expect(replacement.first?.origin == .logged)
  #expect(replacement.first?.confidence == .normal)
  #expect(replacement.first?.e1RMKg == 172)
  #expect(event?.previousMaxE1RMKg == 160)
}

@Test func anomalyThresholdsMatchSpec050() {
  #expect(E1RMPolicy.softJump == 0.10)
  #expect(E1RMPolicy.hardJump == 0.18)
}
