import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func setDisplayNumberUsesRowPositionForBackendOneBasedIndexes() {
  let sets = makeSets(indexes: [1, 2, 3])
  let displayNumbers = sets.map { SetDisplayNumber.number(for: $0, in: sets) }

  #expect(displayNumbers == [1, 2, 3])
}

@Test func setDisplayNumberUsesRowPositionForDemoZeroBasedIndexes() {
  let sets = makeSets(indexes: [0, 1, 2])
  let displayNumbers = sets.map { SetDisplayNumber.number(for: $0, in: sets) }

  #expect(displayNumbers == [1, 2, 3])
}

@Test func draftSetDisplayNumberUsesExerciseRowPosition() {
  let planExerciseID = UUID()
  let drafts = makeSets(indexes: [1, 2, 3]).map { set in
    TodayWorkoutSetRowDraft(
      id: set.id,
      planExerciseID: planExerciseID,
      exerciseID: UUID(),
      exerciseName: "深蹲",
      prescribed: set
    )
  }

  #expect(SetDisplayNumber.number(for: drafts[0], in: drafts) == 1)
  #expect(SetDisplayNumber.number(for: drafts[1], in: drafts) == 2)
  #expect(SetDisplayNumber.number(for: drafts[2], in: drafts) == 3)
}

private func makeSets(indexes: [Int]) -> [PrescribedSet] {
  indexes.map {
    PrescribedSet(id: UUID(), setIndex: $0, weightKg: 100, reps: 5, rpe: 8)
  }
}
