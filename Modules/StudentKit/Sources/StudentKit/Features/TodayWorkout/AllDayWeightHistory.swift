import CoreModels
import Foundation

extension TodayWorkoutViewModel {
  /// Most recent completed, non-failed, non-warm-up weight per catalog exercise.
  nonisolated static func lastWeights(
    from logs: [StudentSetLog],
    planExerciseToExercise: [UUID: UUID]
  ) -> [UUID: Decimal] {
    var latest: [UUID: StudentSetLog] = [:]
    for log in logs where !log.isWarmup && log.completed && !log.failed {
      guard log.weightKg.map({ $0 > 0 }) == true else { continue }
      guard let exerciseID = log.exerciseID ?? planExerciseToExercise[log.planExerciseID] else {
        continue
      }
      if let current = latest[exerciseID],
        current.loggedAt > log.loggedAt
          || (current.loggedAt == log.loggedAt && current.setIndex > log.setIndex)
      {
        continue
      }
      latest[exerciseID] = log
    }
    return latest.compactMapValues(\.weightKg)
  }
}
