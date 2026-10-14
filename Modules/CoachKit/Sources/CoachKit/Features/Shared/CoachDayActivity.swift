import CoreModels
import Foundation
import Networking

/// Ownership changes attribution only within the same plan week.
/// Keep dates until evaluation so roster columns and completion use one calendar.
enum CoachDayActivity {
  static func belongs(
    _ log: CoachSetLogDTO,
    to day: StudentPlanDay?,
    on date: Date,
    days: [StudentPlanDay],
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Bool {
    let owner: StudentPlanDay?
    if let exerciseID = log.planExerciseID {
      let matches = days.filter { $0.exercises.contains { $0.id == exerciseID } }
      // Malformed/legacy projections can repeat an exercise ID across days.
      // Ambiguous ownership must retain the date fallback.
      owner = matches.count == 1 ? matches.first : nil
    } else {
      owner = log.adhoc ? days.first { $0.id == log.planDayID } : nil
    }
    if let owner, let day, owner.weekNumber == day.weekNumber {
      return owner.id == day.id
    }
    return calendar.isDate(log.loggedAt, inSameDayAs: date)
  }

  static func hasTrained(
    _ day: StudentPlanDay,
    days: [StudentPlanDay],
    logs: [CoachSetLogDTO],
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) -> Bool {
    day.completedAt != nil
      || logs.contains {
        $0.completed && belongs($0, to: day, on: day.date, days: days, calendar: calendar)
      }
  }
}
