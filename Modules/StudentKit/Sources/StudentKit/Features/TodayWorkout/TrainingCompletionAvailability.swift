struct TrainingCompletionAvailability: Equatable, Sendable {
  let button: Bool
  let pill: Bool
  let sticky: Bool
}

extension TodayWorkoutPresentation {
  func completionAvailability(isEditable: Bool) -> TrainingCompletionAvailability {
    let button = isEditable && day.completedAt == nil
    return TrainingCompletionAvailability(
      button: button, pill: false, sticky: button)
  }
}
