struct TrainingCompletionAvailability: Equatable, Sendable {
  let button: Bool
  let pill: Bool
  let sticky: Bool
}

enum TrainingCompletionDockContent: Equatable, Sendable {
  case holdToComplete
  case completed(showsUndo: Bool)
  case none
}

extension TodayWorkoutPresentation {
  func completionDock(
    dayState: TodayWorkoutDayState, showingHistory: Bool, waitingForVideos: Bool = false
  ) -> TrainingCompletionDockContent {
    guard !showingHistory else { return .none }
    if case .completed(let canUndo) = dayState {
      return .completed(showsUndo: canUndo)
    }
    return completionAvailability(isEditable: dayState.isEditable).sticky || waitingForVideos
      ? .holdToComplete : .none
  }

  func completionAvailability(isEditable: Bool) -> TrainingCompletionAvailability {
    let button = isEditable && day.completedAt == nil
    return TrainingCompletionAvailability(
      button: button, pill: false, sticky: button)
  }
}
