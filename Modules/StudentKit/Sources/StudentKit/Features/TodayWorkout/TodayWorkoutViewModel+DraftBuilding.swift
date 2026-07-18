import CoreModels
import Foundation

// MARK: - Draft building (pure): plan day + existing logs → set-row drafts.
// Split from TodayWorkoutViewModel.swift to keep that file inside the lint
// file_length budget (see specs/055 NOTES.md).
extension TodayWorkoutViewModel {
  func weightSuggestion(forSetID setID: UUID) -> SetWeightSuggestion? {
    guard let drafts = currentDrafts,
      let draft = drafts.first(where: { $0.id == setID })
    else {
      return nil
    }
    return Self.weightSuggestion(
      forSetID: setID,
      in: drafts,
      currentE1RMKg: exerciseReferences[draft.exerciseID]?.best?.e1RMKg
    )
  }

  nonisolated static func weightSuggestion(
    forSetID setID: UUID,
    in drafts: [SetRowDraft],
    currentE1RMKg: Double?
  ) -> SetWeightSuggestion? {
    guard let targetIndex = drafts.firstIndex(where: { $0.id == setID }) else {
      return nil
    }
    let target = drafts[targetIndex]
    guard target.prescribed.weightKg == nil,
      let targetRPE = target.prescribed.rpe,
      let targetReps = target.prescribed.reps ?? target.prescribed.repsMax
    else {
      return nil
    }

    let previous = drafts[..<targetIndex].reversed().first { candidate in
      candidate.exerciseID == target.exerciseID
        && candidate.completed
        && candidate.actualWeight.map { $0 > 0 } == true
        && (candidate.prescribed.reps ?? candidate.prescribed.repsMax) == targetReps
        && candidate.prescribed.rpe == targetRPE
    }

    let suggestion: SetWeightSuggestion?
    if let previousWeight = previous?.actualWeight {
      suggestion = SetWeightSuggestion(weightKg: previousWeight, basis: .previousSet)
    } else if let currentE1RMKg,
      let rawWeight = E1RMCalculator.suggestedWeight(
        e1RM: currentE1RMKg,
        reps: targetReps,
        rpe: NSDecimalNumber(decimal: targetRPE).doubleValue
      )
    {
      // Forward e1RMs are quotients (weight / intensity), so reversing can land
      // a hair under the exact multiple (49.999…); nudge before flooring or the
      // suggestion drops a whole 2.5 step.
      let steps = (rawWeight / 2.5 + 1e-6).rounded(.down)
      let roundedWeight = steps * 2.5
      suggestion =
        roundedWeight > 0
        ? SetWeightSuggestion(weightKg: Decimal(roundedWeight), basis: .e1RM(currentE1RMKg))
        : nil
    } else {
      suggestion = nil
    }
    guard let suggestion else { return nil }

    // Seed case: nothing logged yet. Rebuild case: the camera flow persists the
    // untouched seed into actualWeight (SetEntrySheet onWillPick) and the sheet
    // re-inits, so an incomplete set whose actual still equals the suggestion
    // is still in the suggested state; any other actual means the student took
    // over and the annotation must not resurface.
    if target.actualWeight == nil { return suggestion }
    if !target.completed, target.actualWeight == suggestion.weightKg { return suggestion }
    return nil
  }

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
