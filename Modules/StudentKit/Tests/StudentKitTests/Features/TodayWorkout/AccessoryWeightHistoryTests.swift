import CoreModels
import Foundation
import Testing

@testable import StudentKit

struct AccessoryWeightHistoryTests {
  static func row(index: Int = 0, accessory: Bool = true, weight: Decimal? = nil)
    -> TodayWorkoutSetRowDraft
  {
    TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "Row",
      isAccessory: accessory,
      prescribed: PrescribedSet(id: UUID(), setIndex: index, weightKg: weight, reps: 12, rpe: 8),
      actualWeight: weight, actualReps: 12, actualRPE: 8)
  }

  @Test func appliesOnlyCorrespondingWeightWithoutCreatingARecord() {
    let original = Self.row()
    let row = AccessoryWeightHistory.apply(to: original, previousWeight: 20)
    #expect(row.actualWeight == 20)
    #expect(row.isHistoryWeightPrefill == true)
    #expect(row.previousAccessoryWeight == 20)
    #expect(row.actualReps == 12)
    #expect(row.actualRPE == 8)
    #expect(!row.hasSavedRecord)
    #expect(!row.completed)
  }
}
