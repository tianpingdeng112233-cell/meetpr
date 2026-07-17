import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func setRecordResultStateMapsDraftOutcomeFlags() {
  let loggedSetID = UUID()
  let unlogged = setDraft(completed: false, failed: false, loggedSetID: nil)
  let videoOnly = setDraft(completed: false, failed: false, loggedSetID: loggedSetID)
  let completed = setDraft(completed: true, failed: false, loggedSetID: loggedSetID)
  let failed = setDraft(completed: true, failed: true, loggedSetID: loggedSetID)

  #expect(SetRecordResultState.resolve(for: unlogged) == .unlogged)
  #expect(SetRecordResultState.resolve(for: videoOnly) == .unlogged)
  #expect(SetRecordResultState.resolve(for: completed) == .completed)
  #expect(SetRecordResultState.resolve(for: failed) == .failed)
  #expect(failed.completed)
}

private func setDraft(
  completed: Bool,
  failed: Bool,
  loggedSetID: UUID?
) -> TodayWorkoutSetRowDraft {
  TodayWorkoutSetRowDraft(
    id: UUID(),
    planExerciseID: UUID(),
    exerciseID: UUID(),
    exerciseName: "深蹲",
    isAccessory: false,
    prescribed: PrescribedSet(id: UUID(), setIndex: 0, weightKg: 140, reps: 5, rpe: 8),
    actualWeight: 140,
    actualReps: failed ? 3 : 5,
    actualRPE: failed ? 9 : 8,
    completed: completed,
    failed: failed,
    loggedSetID: loggedSetID
  )
}
