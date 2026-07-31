import CoreModels
import Foundation
import Testing

@testable import StudentKit

private let recoveryStudentID = UUID()
private let recoveryExerciseID = UUID()
private let recoveryNow = Date(timeIntervalSince1970: 1_782_000_000)

private func recoveryInput(
  weightKg: Decimal,
  setLogID: UUID = UUID()
) -> E1RMRecorder.Input {
  E1RMRecorder.Input(
    studentID: recoveryStudentID,
    exerciseID: recoveryExerciseID,
    family: .squat,
    setLogID: setLogID,
    weightKg: weightKg,
    reps: 1,
    rpe: 10,
    coachRPE: nil,
    completed: true,
    failed: false
  )
}

@Test func resumedDerivationReportsDethronedBaselineNotItsOwnWeight() async throws {
  // Replay already advanced the baseline from this same set log (dethroning
  // 140) before live derivation resumed; the recovered PR must report 140 as
  // the previous record, not the set's own 150.
  let currentSetLogID = UUID()
  let repository = InMemoryE1RMRepository(
    seedWeightBaselines: [
      E1RMWeightBaseline(
        studentId: recoveryStudentID,
        family: .squat,
        maxWeightKg: 150,
        setLogId: currentSetLogID,
        achievedAt: recoveryNow.addingTimeInterval(-60),
        previousMaxWeightKg: 140
      )
    ]
  )
  let recorder = E1RMRecorder(e1rm: repository, now: { recoveryNow })

  let event = await recorder.record(
    recoveryInput(weightKg: 150, setLogID: currentSetLogID)
  )

  #expect(event?.breakthroughWeightKg == 150)
  #expect(event?.previousMaxWeightKg == 140)
  #expect(event?.setLogId == currentSetLogID)
}

@Test func advancingBaselineRecordsTheDethronedValue() async throws {
  let repository = InMemoryE1RMRepository(
    seedWeightBaselines: [
      E1RMWeightBaseline(
        studentId: recoveryStudentID,
        family: .squat,
        maxWeightKg: 140,
        setLogId: UUID(),
        achievedAt: recoveryNow.addingTimeInterval(-86_400)
      )
    ]
  )
  let recorder = E1RMRecorder(e1rm: repository, now: { recoveryNow })

  _ = await recorder.record(recoveryInput(weightKg: 150))

  let baseline = try await repository.fetchWeightBaseline(
    studentId: recoveryStudentID,
    family: .squat
  )
  #expect(baseline?.maxWeightKg == 150)
  #expect(baseline?.previousMaxWeightKg == 140)
}
