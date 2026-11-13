import CoreModels
import Foundation

/// Weight-only presentation for approved accessory history, independent of the paused main-lift rule.
enum AccessoryWeightHistory {
  static func apply(
    to draft: TodayWorkoutSetRowDraft, previousWeight: Decimal?
  ) -> TodayWorkoutSetRowDraft {
    guard draft.isAccessory, !draft.isExtra, !draft.isStudentAdded,
      !draft.prescribed.isBodyweight
    else { return draft }
    switch draft.prescribed.intensity {
    case .percentage, .weightRange: return draft
    default: break
    }
    var result = draft
    result.previousAccessoryWeight = previousWeight.flatMap { !$0.isNaN && $0 >= 0 ? $0 : nil }
    guard let weight = result.previousAccessoryWeight,
      !draft.hasSavedRecord, !draft.completed, !draft.failed,
      draft.prescribed.weightKg == nil, draft.isHistoryWeightPrefill != false,
      draft.actualWeight == nil || draft.isHistoryWeightPrefill == true
    else { return result }
    result.actualWeight = weight
    result.isHistoryWeightPrefill = true
    return result
  }

  static func previous(
    logs: [StudentSetLog], day: StudentPlanDay, studentID: UUID,
    now: Date, planExerciseToExercise: [UUID: UUID]
  ) -> [UUID: [Int: StudentSetLog]] {
    let currentSlots = Set(day.exercises.map(\.id))
    let today = WorkoutDatePolicy.gymDayToday(now: now)
    let eligible = logs.filter {
      $0.studentID == studentID && !currentSlots.contains($0.planExerciseID)
        && $0.loggedAt <= now && $0.loggedDay() <= today
    }
    return Dictionary(
      uniqueKeysWithValues: day.exercises.filter { $0.exercise.isAccessory }.map {
        (
          $0.id,
          AccessoryHistory.previousSession(
            logs: eligible, exerciseID: $0.exercise.id, currentPlanExerciseID: $0.id,
            planExerciseToExercise: planExerciseToExercise)
        )
      })
  }
}
