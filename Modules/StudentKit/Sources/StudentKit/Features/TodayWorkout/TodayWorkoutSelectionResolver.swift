import Foundation

enum TodayWorkoutSelectionResolver {
  static func initialSelection(
    explicitDate: Date?,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Date {
    PlanCalendarDayIdentity.deviceDay(
      containing: explicitDate ?? now,
      calendar: calendar
    )
  }

  static func jumpToTodaySelection(
    from selectedDate: Date,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Date? {
    let deviceToday = PlanCalendarDayIdentity.deviceDay(
      containing: now,
      calendar: calendar
    )
    guard !calendar.isDate(selectedDate, inSameDayAs: deviceToday) else {
      return nil
    }
    return deviceToday
  }
}
