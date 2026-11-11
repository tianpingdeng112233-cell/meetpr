import CoreModels

extension TodayWorkoutSetRowDraft {
  func allDayEffortMode(previous: ActualEffortMode? = nil) -> ActualEffortMode {
    if actualRIR != nil { return .rir }
    if actualRPE != nil { return .rpe }
    return emptyEffortMode(previous: previous)
  }

  func emptyEffortMode(previous: ActualEffortMode? = nil) -> ActualEffortMode {
    switch prescribed.intensity {
    case .rir: return .rir
    case .rpe, .rpeRange: return .rpe
    default: return previous ?? .rpe
    }
  }
}
