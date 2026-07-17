import CoreModels
import Foundation

// MARK: - Draft building (pure): plan day + existing logs → set-row drafts.
// Split from TodayWorkoutViewModel.swift to keep that file inside the lint
// file_length budget (see specs/055 NOTES.md).
extension TodayWorkoutViewModel {
  static func makeDrafts(
    for day: StudentPlanDay,
    existingLogs: [StudentSetLog]
  ) -> [SetRowDraft] {
    day.exercises.flatMap { exercise in
      exercise.prescribedSets.map { set in
        makeDraft(exercise: exercise, set: set, existingLogs: existingLogs)
      }
    }
  }

  static func makeDraft(
    exercise: StudentPlanExercise,
    set: PrescribedSet,
    existingLogs: [StudentSetLog]
  ) -> SetRowDraft {
    let existingLog = existingLogs.first {
      $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
    }
    return SetRowDraft(
      id: set.id,
      planExerciseID: exercise.id,
      exerciseID: exercise.exercise.id,
      exerciseName: exercise.exercise.name,
      isAccessory: exercise.exercise.isAccessory,
      prescribed: set,
      actualWeight: existingLog?.weightKg ?? set.weightKg,
      actualReps: existingLog?.reps ?? set.reps,
      actualRPE: existingLog?.rpe ?? set.rpe ?? 8,
      completed: existingLog?.completed ?? false,
      failed: existingLog?.failed ?? false,
      loggedSetID: existingLog?.id
    )
  }
}
