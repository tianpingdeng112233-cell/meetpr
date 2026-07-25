import DesignSystem

extension StudentRosterRowModel {
  var statusTone: MeetPRSemanticTone {
    if triageSignals.contains(where: {
      if case .notTrained = $0 { return true }
      return false
    }) {
      return .notCompleted
    }
    if !triageSignals.isEmpty {
      return .danger
    }
    if case .abnormal = student.status {
      return .danger
    }
    if case .inEvaluation = student.status {
      return .inProgress
    }
    if plannedTrainingDays > 0, completedTrainingDays >= plannedTrainingDays {
      return .completed
    }
    return .neutral
  }
}
