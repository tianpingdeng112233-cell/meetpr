import Foundation

struct TrainingWeekCellPresentation: Equatable, Sendable {
  let weekday: String
  let caption: String
  let isBehind: Bool
  let accessibilityLabel: String

  var lines: [String] { [weekday, caption] }

  init(
    cell: TrainingSequenceCalendarCell, today: Date, locale: Locale = .current,
    calendar: Calendar = WorkoutDatePolicy.deviceCalendar
  ) {
    var style = Date.FormatStyle().weekday(.abbreviated).locale(locale)
    style.calendar = PlanCalendarDayIdentity.utcCalendar
    style.timeZone = PlanCalendarDayIdentity.utcTimeZone
    weekday = cell.date.formatted(style)
    if let item = cell.trainingDay {
      isBehind = TrainingSequenceLayout.isBehind(item.day, today: today, calendar: calendar)
      let parts = PlanCalendarDayIdentity.utcCalendar.dateComponents(
        [.month, .day], from: cell.date)
      caption =
        isBehind
        ? StudentStrings.localized(.trainingWeekBehind, locale: locale)
        : "\(parts.month ?? 0)/\(parts.day ?? 0)"
      let code = "W\(item.day.weekNumber)D\(item.dayNumber), \(weekday)"
      accessibilityLabel =
        isBehind
        ? StudentStrings.replacing(.trainingWeekBehindAccessibility, values: [code], locale: locale)
        : "\(code) \(caption)"
    } else {
      isBehind = false
      caption = StudentStrings.localized(.trainingWeekRest, locale: locale)
      accessibilityLabel = StudentStrings.replacing(
        .trainingWeekRestAccessibility, values: [weekday], locale: locale)
    }
  }
}

struct TrainingWeekStatusPresentation: Equatable, Sendable {
  let text: String
  let accessibilityLabel: String

  init(state: TrainingSequenceDayState, daysBehind: Int, locale: Locale = .current) {
    if state == .current && daysBehind > 0 {
      text = StudentStrings.trainingDaysBehind(daysBehind, locale: locale)
      accessibilityLabel = StudentStrings.trainingDaysBehind(
        daysBehind, accessibility: true, locale: locale)
    } else {
      let key: StudentStrings.Key =
        switch state {
        case .current: .trainingWeekCurrent
        case .upcoming: .trainingWeekUpcoming
        case .completed: .trainingWeekCompleted
        }
      text = StudentStrings.localized(key, locale: locale)
      accessibilityLabel = text
    }
  }
}
