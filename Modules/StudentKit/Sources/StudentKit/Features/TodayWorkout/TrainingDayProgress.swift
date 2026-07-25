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
  var semanticTone: MeetPRSemanticTone {
    switch self {
    case .noPlan:
      .neutral
    case .notStarted:
      .notCompleted
    case .partial:
      .inProgress
    case .complete:
      .completed
    }
  }

  var dotColor: Color {
    self == .noPlan ? semanticTone.color.opacity(0.4) : semanticTone.color
  }
}
