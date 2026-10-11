import CoreModels
import Foundation

enum AccessoryHistory {
  static func previousSession(
    logs: [StudentSetLog], exerciseID: UUID, currentPlanExerciseID: UUID,
    planExerciseToExercise: [UUID: UUID]
  ) -> [Int: StudentSetLog] {
    let eligible = logs.filter {
      ($0.exerciseID ?? planExerciseToExercise[$0.planExerciseID]) == exerciseID
        && $0.planExerciseID != currentPlanExerciseID && $0.completed && !$0.failed && !$0.assumed
    }
    guard
      let last = eligible.max(by: {
        dateKey($0) == dateKey($1) ? $0.loggedAt < $1.loggedAt : dateKey($0) < dateKey($1)
      })
    else { return [:] }
    return Dictionary(
      eligible.filter { $0.planExerciseID == last.planExerciseID && dateKey($0) == dateKey(last) }
        .map { ($0.setIndex, $0) },
      uniquingKeysWith: { $0.loggedAt > $1.loggedAt ? $0 : $1 })
  }

  private static func dateKey(_ log: StudentSetLog) -> String {
    log.loggedDate
      ?? WorkoutDatePolicy.gymDayToday(now: log.loggedAt).formatted(.iso8601.year().month().day())
  }
}
