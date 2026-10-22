import CoreModels
import Foundation

/// Adds execution rows without changing the coach's prescription.
enum StudentAddedRows {
  static let limit = 10

  static func extra(
    exercise: StudentPlanExercise, drafts: [TodayWorkoutSetRowDraft]
  ) -> TodayWorkoutSetRowDraft? {
    let rows = drafts.filter { $0.planExerciseID == exercise.id }
    guard rows.count(where: \.isExtra) < limit else { return nil }
    let previous = rows.filter {
      $0.loggedSetID != nil && !$0.assumed && ($0.completed || $0.failed)
    }
    .max { ($0.recordedAt ?? .distantPast) < ($1.recordedAt ?? .distantPast) }
    let last = exercise.prescribedSets.last
    let index = max(
      exercise.prescribedSets.count, (rows.map(\.prescribed.setIndex).max() ?? -1) + 1)
    return makeExtra(
      exercise: exercise,
      set: PrescribedSet(id: UUID(), setIndex: index),
      weight: previous?.actualWeight ?? last?.weightKg,
      reps: previous?.actualReps ?? last?.reps ?? last?.repsMax)
  }

  static func restoredExtras(
    exercise: StudentPlanExercise, logs: [StudentSetLog]
  ) -> [TodayWorkoutSetRowDraft] {
    logs.filter {
      $0.planExerciseID == exercise.id && $0.setIndex >= exercise.prescribedSets.count
    }.sorted { $0.setIndex < $1.setIndex }.map { log in
      var draft = makeExtra(
        exercise: exercise, set: PrescribedSet(id: log.id, setIndex: log.setIndex),
        weight: log.weightKg, reps: log.reps)
      draft.actualRPE = log.rpe
      draft.applyPersistResult(log, completed: log.completed, failed: log.failed)
      return draft
    }
  }

  private static func makeExtra(
    exercise: StudentPlanExercise, set: PrescribedSet, weight: Decimal?, reps: Int?
  ) -> TodayWorkoutSetRowDraft {
    var draft = TodayWorkoutSetRowDraft(
      id: set.id, planExerciseID: exercise.id, exerciseID: exercise.exercise.id,
      exerciseName: exercise.exercise.name, exerciseNameEn: exercise.exercise.nameEn,
      isCatalogExercise: exercise.exercise.createdByCoachID == nil,
      isAccessory: exercise.exercise.isAccessory,
      isMainLift: exercise.exercise.exerciseType == .mainLift,
      planExerciseSortOrder: exercise.sequenceIndex, prescribed: set,
      actualWeight: weight, actualReps: reps)
    draft.isExtra = true
    return draft
  }
}
