import Foundation

public enum ExerciseNoteDayResolver {
  public static func resolve(_ reference: ExerciseRefV1, days: [StudentPlanDay]) -> StudentPlanDay?
  {
    if let id = reference.planDayID { return days.first { $0.id == id } }
    return days.first {
      $0.date.formatted(.iso8601.year().month().day().dateSeparator(.dash)) == reference.dayDate
    }
  }
}
