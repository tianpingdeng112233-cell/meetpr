import CoreModels
import Foundation

/// Sequence editability is independent of recommended calendar dates.
enum FlexibleTrainingDay {
  static func canWrite(_ day: StudentPlanDay, in days: [StudentPlanDay]) -> Bool {
    day.completedAt == nil
      && days.contains { $0.id == day.id && $0.completedAt == nil }
      && day.weekNumber == StudentPlanSequence(days: days).cursorDay?.weekNumber
  }

  static func defaultDay(
    days: [StudentPlanDay], logs: [StudentSetLog], added: [StudentAddedSetLog] = [], now: Date,
    calendar: Calendar = .current
  ) -> StudentPlanDay? {
    let today = StudentSetLog.gymDay(of: now, calendar: calendar)
    var candidates: [(day: StudentPlanDay, timestamp: Date)] = []
    for log in logs
    where !log.assumed && (log.completed || log.failed)
      && log.loggedDay(calendar: calendar) == today
    {
      if let day = days.first(where: { day in
        canWrite(day, in: days) && day.exercises.contains { $0.id == log.planExerciseID }
      }) {
        candidates.append((day, log.loggedAt))
      }
    }
    for log in added where !log.assumed && (log.completed || log.failed) {
      let parts = log.loggedDate?.split(separator: "-").compactMap { Int($0) } ?? []
      let date =
        parts.count == 3
        ? calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        : StudentSetLog.gymDay(of: log.loggedAt, calendar: calendar)
      if date == today,
        let day = days.first(where: { $0.id == log.planDayID && canWrite($0, in: days) })
      {
        candidates.append((day, log.loggedAt))
      }
    }
    if let latest = candidates.max(by: { $0.timestamp < $1.timestamp }) { return latest.day }
    return StudentPlanSequence(days: days).cursorDay
  }

  static func canUndo(_ dayID: UUID, days: [StudentPlanDay], now: Date) -> Bool {
    let latest = days.filter { $0.completedAt != nil }.max {
      ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
    }
    guard latest?.id == dayID, let date = latest?.completedAt else { return false }
    return WorkoutDatePolicy.gymDayRange(containing: now).contains(date)
  }
}
