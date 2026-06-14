import CoreModels
import DesignSystem
import SwiftUI

enum TrainingDayCompletionState: Equatable, Sendable {
  case noPlan
  case notStarted
  case partial
  case complete
}

struct TrainingDayProgress: Equatable, Sendable {
  let completed: Int
  let total: Int
  let state: TrainingDayCompletionState

  init(day: StudentPlanDay?, logs: [StudentSetLog]) {
    guard let day, !day.exercises.isEmpty else {
      self.completed = 0
      self.total = 0
      self.state = .noPlan
      return
    }

    let counts = StudentFormatting.completedCount(for: day, logs: logs)
    self.completed = counts.completed
    self.total = counts.total

    if counts.total > 0 && counts.completed == counts.total {
      self.state = .complete
    } else if counts.completed > 0 {
      self.state = .partial
    } else {
      self.state = .notStarted
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension TrainingDayCompletionState {
  var dotColor: Color {
    switch self {
    case .noPlan:
      Color.MeetPR.fgTertiary.opacity(0.4)
    case .notStarted:
      Color.MeetPR.brandRed
    case .partial:
      Color.MeetPR.amber
    case .complete:
      Color.MeetPR.green
    }
  }
}
