import CoreModels
import Foundation

enum StudentAddedPreviousSession {
  static func find(
    draft: TodayWorkoutSetRowDraft, records: StudentWorkoutLogs, days: [StudentPlanDay],
    calendar: Calendar
  ) -> (planned: StudentSetLog?, added: StudentAddedSetLog?) {
    let slots = Set(
      days.flatMap(\.exercises).filter { $0.exercise.id == draft.exerciseID }.map(\.id))
    let currentSlots = Set(
      days.first { $0.id == draft.studentAddedDayID }?.exercises.map(\.id) ?? [])
    let planned = records.planned.filter {
      ($0.exerciseID == draft.exerciseID || slots.contains($0.planExerciseID))
        && !currentSlots.contains($0.planExerciseID) && $0.completed && !$0.failed && !$0.assumed
    }
    let added = records.added.filter {
      $0.exerciseID == draft.exerciseID && $0.planDayID != draft.studentAddedDayID
        && $0.completed && !$0.failed && !$0.assumed
    }
    let dates =
      planned.map { $0.loggedDay(calendar: calendar) }
      + added.map { day($0, calendar: calendar) }
    guard let latest = dates.max() else { return (nil, nil) }
    let previousPlanned = planned.filter {
      $0.loggedDay(calendar: calendar) == latest && $0.setIndex == draft.prescribed.setIndex
    }.max { $0.loggedAt < $1.loggedAt }
    let previousAdded = added.filter {
      day($0, calendar: calendar) == latest && $0.setIndex == draft.prescribed.setIndex
    }.max { $0.loggedAt < $1.loggedAt }
    if let previousAdded, previousAdded.loggedAt > (previousPlanned?.loggedAt ?? .distantPast) {
      return (nil, previousAdded)
    }
    return (previousPlanned, nil)
  }

  private static func day(_ log: StudentAddedSetLog, calendar: Calendar) -> Date {
    let parts = log.loggedDate?.split(separator: "-").compactMap { Int($0) } ?? []
    if parts.count == 3,
      let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    {
      return date
    }
    return StudentSetLog.gymDay(of: log.loggedAt, calendar: calendar)
  }
}
