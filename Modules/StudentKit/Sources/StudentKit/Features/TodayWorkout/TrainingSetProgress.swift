/// Decorative segments; the hero's existing position text remains the spoken progress.
enum TrainingSetProgress {
  enum Segment: Equatable, Sendable {
    case complete, failed, current, upcoming
  }

  static func segments(_ drafts: [TodayWorkoutViewModel.SetRowDraft]) -> [Segment] {
    let current = drafts.firstIndex { $0.needsTrainingResult }
    return drafts.enumerated().map { index, draft in
      if draft.needsTrainingResult { return index == current ? .current : .upcoming }
      return draft.failed ? .failed : .complete
    }
  }
}
