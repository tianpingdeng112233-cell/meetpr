import Foundation

/// The screen consumes this only in editable recording mode. Other routes keep their old layout.
struct TrainingFlowPresentation: Equatable, Sendable {
  let completed: [TodayWorkoutPresentation.Exercise]
  let hero: TodayWorkoutPresentation.Exercise?
  let belowHero: [TodayWorkoutPresentation.Exercise]
  let completion: TrainingCompletionAvailability
  let progress: TodayWorkoutProgress

  init(presentation: TodayWorkoutPresentation) {
    let partition = TrainingExerciseProgress(exercises: presentation.exercises)
    completed = partition.completed
    hero = partition.active
    belowHero = ([partition.active].compactMap { $0 } + partition.remaining)
      .sorted { $0.stableIndex < $1.stableIndex }
    completion = presentation.completionAvailability(isEditable: true)
    // Reuse existing position/remaining copy without changing history or summary semantics.
    let drafts = presentation.exercises.flatMap(\.rows).map { row in
      var draft = row.draft
      draft.completed = !draft.needsTrainingResult
      return draft
    }
    progress = TodayWorkoutProgress(day: presentation.day, drafts: drafts)
  }

  var currentRow: TodayWorkoutPresentation.Row? {
    hero?.rows.first { $0.draft.needsTrainingResult }
  }
}

extension TodayWorkoutPresentation {
  func trainingFlow(isEditable: Bool) -> TrainingFlowPresentation? {
    guard isEditable, day.completedAt == nil, heroMode == .recording else { return nil }
    return TrainingFlowPresentation(presentation: self)
  }
}

extension TodayWorkoutPresentation.Exercise {
  var trainingCompletedText: String {
    StudentStrings.replacing(
      rows.count == 1 ? .trainingFlowCompletedOne : .trainingFlowCompletedMany,
      values: [String(rows.count)])
  }

  var trainingCompletedAccessibility: String {
    StudentStrings.replacing(
      rows.count == 1
        ? .trainingFlowCompletedAccessibilityOne : .trainingFlowCompletedAccessibilityMany,
      values: [name, String(rows.count)])
  }
}
