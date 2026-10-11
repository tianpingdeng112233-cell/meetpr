import Foundation

/// Display-only partition. Assumed history never advances the recording hero.
struct TrainingExerciseProgress: Equatable, Sendable {
  let completed: [TodayWorkoutPresentation.Exercise]
  let active: TodayWorkoutPresentation.Exercise?
  let remaining: [TodayWorkoutPresentation.Exercise]

  init(exercises: [TodayWorkoutPresentation.Exercise]) {
    let ordered = exercises.sorted { $0.stableIndex < $1.stableIndex }
    let completed = ordered.filter {
      !$0.rows.isEmpty && $0.rows.allSatisfy { !$0.draft.needsTrainingResult }
    }
    let unfinished = ordered.filter { exercise in !completed.contains { $0.id == exercise.id } }
    let active = unfinished.first { $0.rows.contains { $0.draft.needsTrainingResult } }
    self.completed = completed
    self.active = active
    self.remaining = unfinished.filter { $0.id != active?.id }
  }
}

extension TodayWorkoutViewModel.SetRowDraft {
  var needsTrainingResult: Bool { assumed || !(completed || failed) }
}
