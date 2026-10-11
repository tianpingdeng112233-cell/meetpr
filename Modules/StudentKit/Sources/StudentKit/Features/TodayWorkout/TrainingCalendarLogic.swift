import CoreModels
import Foundation

enum TrainingSequenceDayState: Equatable, Sendable {
  case completed
  case current
  case upcoming
}

struct TrainingSequenceDay: Equatable, Identifiable, Sendable {
  let day: StudentPlanDay
  let dayNumber: Int
  let state: TrainingSequenceDayState
  let isSelected: Bool

  var id: UUID { day.id }
}

struct TrainingSequenceWeek: Equatable, Identifiable, Sendable {
  let weekNumber: Int
  let days: [TrainingSequenceDay]

  var id: Int { weekNumber }
  var calendarCells: [TrainingSequenceCalendarCell] {
    let calendar = PlanCalendarDayIdentity.utcCalendar
    guard let first = days.first, let last = days.last else { return [] }
    let start = calendar.startOfDay(for: first.day.date)
    let end = calendar.startOfDay(for: last.day.date)
    let count = max(7, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    return (0..<count).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
      if let day = days.first(where: { calendar.isDate($0.day.date, inSameDayAs: date) }) {
        return .training(day)
      }
      return .rest(date)
    }
  }
  var completedCount: Int { days.filter { $0.state == .completed }.count }
  var state: TrainingSequenceDayState {
    if days.contains(where: { $0.state == .current }) { return .current }
    return completedCount == days.count ? .completed : .upcoming
  }
}

struct TrainingSequencePage: Equatable, Sendable {
  let weeks: [TrainingSequenceWeek]
  let currentWeekNumber: Int?
  let visibleWeek: TrainingSequenceWeek?
  let showsBackToToday: Bool
  let currentSelection: UUID?

  var previousWeekSelection: UUID? { selection(offset: -1) }
  var nextWeekSelection: UUID? { selection(offset: 1) }
  var showsWeekIndicators: Bool { !weeks.isEmpty && weeks.count <= 8 }

  private func selection(offset: Int) -> UUID? {
    guard let index = weeks.firstIndex(where: { $0.id == visibleWeek?.id }),
      weeks.indices.contains(index + offset)
    else { return nil }
    let week = weeks[index + offset]
    if week.weekNumber == currentWeekNumber { return currentSelection }
    return week.days.first?.id
  }
}

enum TrainingSequenceLayout {
  static func isBehind(
    _ day: StudentPlanDay, today: Date, calendar: Calendar = WorkoutDatePolicy.deviceCalendar
  ) -> Bool {
    day.completedAt == nil && recommendationAge(day, today: today, calendar: calendar) > 0
  }

  static func daysBehind(
    days: [StudentPlanDay], today: Date, calendar: Calendar = WorkoutDatePolicy.deviceCalendar
  ) -> Int {
    guard let cursor = StudentPlanSequence(days: days).cursorDay else { return 0 }
    return max(0, recommendationAge(cursor, today: today, calendar: calendar))
  }

  private static func recommendationAge(
    _ day: StudentPlanDay, today: Date, calendar: Calendar
  ) -> Int {
    PlanCalendarDayIdentity.dayOffset(
      fromPlanDate: day.date, toSelectedDate: today, selectedCalendar: calendar) ?? 0
  }

  static func page(days: [StudentPlanDay], selectedDayID: UUID?) -> TrainingSequencePage {
    let selection = initialSelection(days: days, explicitDayID: selectedDayID)
    let weeks = makeWeeks(days: days, selectedDayID: selection)
    return TrainingSequencePage(
      weeks: weeks,
      currentWeekNumber: currentWeekNumber(days: days),
      visibleWeek: weeks.first { $0.days.contains { $0.isSelected } },
      showsBackToToday: selection != initialSelection(days: days, explicitDayID: nil),
      currentSelection: initialSelection(days: days, explicitDayID: nil)
    )
  }

  /// The cursor order is defined only by backend spec 035 §术语与排序正典.
  static func makeWeeks(
    days: [StudentPlanDay],
    selectedDayID: UUID?
  ) -> [TrainingSequenceWeek] {
    let sequence = StudentPlanSequence(days: days)
    let cursorID = sequence.cursorDay?.id
    let groups = Dictionary(grouping: sequence.orderedDays, by: \.weekNumber)
    return groups.keys.sorted().map { weekNumber in
      let weekDays = groups[weekNumber] ?? []
      let numbers = StudentPlanSequence.dayNumbers(inWeek: weekDays)
      return TrainingSequenceWeek(
        weekNumber: weekNumber,
        days: (groups[weekNumber] ?? []).map { day in
          TrainingSequenceDay(
            day: day,
            dayNumber: numbers[day.id] ?? 1,
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

}

enum TrainingSequenceText {
  static func code(for day: StudentPlanDay, in days: [StudentPlanDay]) -> String {
    let week = days.filter { $0.weekNumber == day.weekNumber }
    let number = StudentPlanSequence.dayNumbers(inWeek: week)[day.id]
    return "W\(day.weekNumber)D\(number.map(String.init) ?? "—")"
  }

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

  static func dayName(_ day: StudentPlanDay, locale: Locale = .current) -> String {
    let families = MainLiftExerciseFamilyResolver.families(in: day)
    guard !families.isEmpty else {
      return StudentStrings.localized(.trainingCalendarLogic009, locale: locale)
    }
    if families.count == 3 {
      return StudentStrings.localized(.trainingCalendarLogic010, locale: locale)
    }
    let separator = locale.language.languageCode?.identifier == "en" ? " / " : ""
    let names = families.map { $0.studentDisplayName(locale: locale) }.joined(separator: separator)
    return StudentStrings.replacing(.trainingCalendarLogic011, values: [names], locale: locale)
  }

  static func unlockMessage(after day: StudentPlanDay) -> String {
    StudentStrings.replacing(
      .trainingCalendarLogic012,
      values: ["\(day.weekNumber)", "\(DashboardTodayPresentation.dayName(day))"])
  }

  static func exerciseSummary(_ day: StudentPlanDay) -> String {
    let sets = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    return StudentStrings.replacing(.todayWorkoutScreen018, values: ["\(day.exercises.count)"])
      + StudentStrings.replacing(.todayWorkoutScreen019, values: ["\(sets)"])
  }
}
