struct TrainingCompletionAvailability: Equatable, Sendable {
  let button: Bool
  let pill: Bool
  let sticky: Bool
}

extension TodayWorkoutPresentation {
  func completionAvailability(isEditable: Bool) -> TrainingCompletionAvailability {
    let button = isEditable && day.completedAt == nil && allowsManualCompletion
    let remaining = exercises.flatMap(\.rows).contains { $0.draft.needsTrainingResult }
    return TrainingCompletionAvailability(
      button: button, pill: button && remaining, sticky: button && !remaining)
  }
}
