import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func setDisplayNumberConvertsZeroBasedIndexesAtDisplayBoundary() {
  let sets = makeSets(indexes: [0, 1, 2])
  let displayNumbers = sets.map(SetDisplayNumber.number(for:))

  #expect(displayNumbers == [1, 2, 3])
}

@Test func draftSetDisplayNumberUsesZeroBasedPrescribedIndex() {
  let planExerciseID = UUID()
  let drafts = makeSets(indexes: [0, 1, 2]).map { set in
    TodayWorkoutSetRowDraft(
      id: set.id,
      planExerciseID: planExerciseID,
      exerciseID: UUID(),
      exerciseName: "深蹲",
      isAccessory: false,
      prescribed: set
    )
  }

  #expect(SetDisplayNumber.number(for: drafts[0]) == 1)
  #expect(SetDisplayNumber.number(for: drafts[1]) == 2)
  #expect(SetDisplayNumber.number(for: drafts[2]) == 3)
}

private func makeSets(indexes: [Int]) -> [PrescribedSet] {
  indexes.map {
    PrescribedSet(id: UUID(), setIndex: $0, weightKg: 100, reps: 5, rpe: 8)
  }
}
