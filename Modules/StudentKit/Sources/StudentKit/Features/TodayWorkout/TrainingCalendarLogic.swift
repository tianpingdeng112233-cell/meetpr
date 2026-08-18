import CoreModels
import Foundation

enum TrainingSequenceDayState: Equatable, Sendable {
  case completed
  case current
  case upcoming
}

struct TrainingSequenceDay: Equatable, Identifiable, Sendable {
  let day: StudentPlanDay
  let state: TrainingSequenceDayState
  let isSelected: Bool

  var id: UUID { day.id }
}

struct TrainingSequenceWeek: Equatable, Identifiable, Sendable {
  let weekNumber: Int
  let days: [TrainingSequenceDay]

  var id: Int { weekNumber }
}

enum TrainingSequenceLayout {
  /// The cursor order is defined only by backend spec 035 §术语与排序正典.
  static func makeWeeks(
    days: [StudentPlanDay],
    selectedDayID: UUID?
  ) -> [TrainingSequenceWeek] {
    let sequence = StudentPlanSequence(days: days)
    let cursorID = sequence.cursorDay?.id
    let groups = Dictionary(grouping: sequence.orderedDays, by: \.weekNumber)
    return groups.keys.sorted().map { weekNumber in
      TrainingSequenceWeek(
        weekNumber: weekNumber,
        days: (groups[weekNumber] ?? []).map { day in
          TrainingSequenceDay(
            day: day,
            state: day.completedAt != nil
              ? .completed : (day.id == cursorID ? .current : .upcoming),
            isSelected: day.id == selectedDayID
          )
        }
      )
    }
  }

  static func initialSelection(days: [StudentPlanDay], explicitDayID: UUID?) -> UUID? {
    let sequence = StudentPlanSequence(days: days)
    if let explicitDayID, sequence.orderedDays.contains(where: { $0.id == explicitDayID }) {
      return explicitDayID
    }
    return sequence.cursorDay?.id ?? sequence.orderedDays.last?.id
  }

  static func currentWeekNumber(days: [StudentPlanDay]) -> Int? {
    let sequence = StudentPlanSequence(days: days)
    return (sequence.cursorDay ?? sequence.orderedDays.last)?.weekNumber
  }

  /// The plan summary lists the cursor week onward only (design prototype:
  /// `PLAN.slice(CUR_WK)`) — fully behind weeks would otherwise wear the
  /// future-week "M 节 · X/X 起" meta.
  static func weeksFromCurrent(
    days: [StudentPlanDay],
    selectedDayID: UUID?
  ) -> [TrainingSequenceWeek] {
    let weeks = makeWeeks(days: days, selectedDayID: selectedDayID)
    guard let currentWeekNumber = currentWeekNumber(days: days) else { return weeks }
    return weeks.filter { $0.weekNumber >= currentWeekNumber }
  }
}

enum TrainingSequenceText {
  static func recommendation(_ date: Date) -> String {
    let calendar = PlanCalendarDayIdentity.utcCalendar
    let components = calendar.dateComponents([.month, .day, .weekday], from: date)
    let weekdays = [
      StudentStrings.localized(.trainingCalendarLogic001),
      StudentStrings.localized(.trainingCalendarLogic002),
      StudentStrings.localized(.trainingCalendarLogic003),
      StudentStrings.localized(.trainingCalendarLogic004),
      StudentStrings.localized(.trainingCalendarLogic005),
      StudentStrings.localized(.trainingCalendarLogic006),
      StudentStrings.localized(.trainingCalendarLogic007),
    ]
    let weekdayIndex = (components.weekday ?? 1) - 1
    let weekday = weekdays.indices.contains(weekdayIndex) ? weekdays[weekdayIndex] : ""
    return StudentStrings.replacing(
      .trainingCalendarLogic008,
      values: ["\(components.month ?? 0)", "\(components.day ?? 0)", "\(weekday)"])
  }

  static func dayName(_ day: StudentPlanDay) -> String {
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    guard !families.isEmpty else { return StudentStrings.localized(.trainingCalendarLogic009) }
    if families.count == 3 { return StudentStrings.localized(.trainingCalendarLogic010) }
    return families.map(\.studentDisplayName).joined()
      + StudentStrings.localized(.trainingCalendarLogic011)
  }

  static func weekSummary(_ days: [TrainingSequenceDay]) -> String {
    days.map { dayName($0.day) }.joined(separator: " · ")
  }

  static func shortDate(_ date: Date) -> String {
    let components = PlanCalendarDayIdentity.utcCalendar.dateComponents([.month, .day], from: date)
    return "\(components.month ?? 0)/\(components.day ?? 0)"
  }

  static func unlockMessage(after day: StudentPlanDay) -> String {
    StudentStrings.replacing(
      .trainingCalendarLogic012,
      values: ["\(day.weekNumber)", "\(DashboardTodayPresentation.dayName(day))"])
  }

  static func exerciseSummary(_ day: StudentPlanDay) -> String {
    let sets = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    return StudentStrings.replacing(
      .trainingCalendarLogic013, values: ["\(day.exercises.count)", "\(sets)"])
  }
}
