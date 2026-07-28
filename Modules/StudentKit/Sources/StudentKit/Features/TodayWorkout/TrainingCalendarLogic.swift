import CoreModels
import Foundation

enum TrainingCalendarMode: String, CaseIterable, Hashable, Identifiable, Sendable {
  case week
  case month

  var id: Self { self }
}

struct TrainingCalendarDay: Equatable, Identifiable, Sendable {
  let date: Date
  let planDay: StudentPlanDay?
  let progress: TrainingDayProgress
  let isInDisplayedMonth: Bool
  let isSelected: Bool
  let isToday: Bool

  var id: Date { date }
}

/// The view-state inputs for laying out a calendar period (keeps `makeDays`
/// within the parameter-count limit).
struct TrainingCalendarPeriod: Equatable, Sendable {
  let displayedDate: Date
  let selectedDate: Date
  let today: Date
  let mode: TrainingCalendarMode
}

enum TrainingCalendarLayout {
  static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
    let start = startOfWeek(containing: date, calendar: calendar)
    return dates(startingAt: start, count: 7, calendar: calendar)
  }

  static func monthDates(containing date: Date, calendar: Calendar) -> [Date] {
    guard let interval = calendar.dateInterval(of: .month, for: date) else {
      return weekDates(containing: date, calendar: calendar)
    }
    let first = calendar.startOfDay(for: interval.start)
    let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? first
    let start = startOfWeek(containing: first, calendar: calendar)
    let end = endOfWeek(containing: last, calendar: calendar)
    return dates(from: start, through: end, calendar: calendar)
  }

  static func move(_ date: Date, mode: TrainingCalendarMode, by value: Int, calendar: Calendar)
    -> Date
  {
    let component: Calendar.Component = mode == .week ? .weekOfYear : .month
    return calendar.date(byAdding: component, value: value, to: date) ?? date
  }

  static func makeDays(
    period: TrainingCalendarPeriod,
    cycleDays: [StudentPlanDay],
    logs: [StudentSetLog],
    calendar: Calendar
  ) -> [TrainingCalendarDay] {
    let dates =
      period.mode == .week
      ? weekDates(containing: period.displayedDate, calendar: calendar)
      : monthDates(containing: period.displayedDate, calendar: calendar)
    return dates.map { date in
      let planDay = cycleDays.first {
        PlanCalendarDayIdentity.matches(
          planDate: $0.date,
          selectedDate: date,
          selectedCalendar: calendar
        )
      }
      return TrainingCalendarDay(
        date: date,
        planDay: planDay,
        progress: TrainingDayProgress(day: planDay, logs: logs),
        isInDisplayedMonth: calendar.isDate(
          date, equalTo: period.displayedDate, toGranularity: .month),
        isSelected: calendar.isDate(date, inSameDayAs: period.selectedDate),
        isToday: calendar.isDate(date, inSameDayAs: period.today)
      )
    }
  }

  static func weekdayLabels(calendar: Calendar) -> [String] {
    let symbols = ["日", "一", "二", "三", "四", "五", "六"]
    let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
    return Array(symbols[start...]) + Array(symbols[..<start])
  }

  private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    components.weekday = calendar.firstWeekday
    return calendar.date(from: components).map(calendar.startOfDay(for:))
      ?? calendar.startOfDay(for: date)
  }

  private static func endOfWeek(containing date: Date, calendar: Calendar) -> Date {
    let start = startOfWeek(containing: date, calendar: calendar)
    return calendar.date(byAdding: .day, value: 6, to: start) ?? start
  }

  private static func dates(startingAt start: Date, count: Int, calendar: Calendar) -> [Date] {
    var result: [Date] = []
    var current = calendar.startOfDay(for: start)
    for _ in 0..<count {
      result.append(current)
      guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
      current = next
    }
    return result
  }

  private static func dates(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
    var result: [Date] = []
    var current = calendar.startOfDay(for: start)
    while calendar.compare(current, to: end, toGranularity: .day) != .orderedDescending {
      result.append(current)
      guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
      current = next
    }
    return result
  }
}

enum TrainingCalendarText {
  private static let shortWeekdays = [
    "周日", "周一", "周二", "周三", "周四", "周五", "周六",
  ]
  private static let longWeekdays = [
    "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六",
  ]
  private static let months = [
    "一月", "二月", "三月", "四月", "五月", "六月",
    "七月", "八月", "九月", "十月", "十一月", "十二月",
  ]

  static func weekday(for date: Date, calendar: Calendar) -> String {
    let index = calendar.component(.weekday, from: date) - 1
    return shortWeekdays.indices.contains(index) ? shortWeekdays[index] : ""
  }

  static func collapsedDate(for date: Date, calendar: Calendar = .current) -> String {
    let monthIndex = calendar.component(.month, from: date) - 1
    let month = months.indices.contains(monthIndex) ? months[monthIndex] : ""
    let day = calendar.component(.day, from: date)
    let weekdayIndex = calendar.component(.weekday, from: date) - 1
    let weekday = longWeekdays.indices.contains(weekdayIndex) ? longWeekdays[weekdayIndex] : ""
    return "\(month)\(day)日 · \(weekday)"
  }
}
