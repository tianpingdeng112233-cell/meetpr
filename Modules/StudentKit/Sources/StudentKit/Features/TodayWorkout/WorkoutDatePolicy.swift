import Foundation

/// Gym-day bucketing for log timestamps and same-device-gym-day completion undo.
/// Sequence editability is cursor-based and must never call this policy.
enum WorkoutDatePolicy {
  static let gymDayCutoffHour = 4

  static var deviceCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    return calendar
  }

  /// The start of the local calendar date owning this gym-day timestamp.
  static func gymDayToday(
    now: Date = Date(),
    calendar: Calendar = deviceCalendar
  ) -> Date {
    let localDay = calendar.startOfDay(for: now)
    guard calendar.component(.hour, from: now) < gymDayCutoffHour else {
      return localDay
    }
    return calendar.date(byAdding: .day, value: -1, to: localDay) ?? localDay
  }

  static func gymDayRange(
    containing timestamp: Date,
    calendar: Calendar = deviceCalendar
  ) -> ClosedRange<Date> {
    let gymDay = gymDayToday(now: timestamp, calendar: calendar)
    let start =
      calendar.date(
        bySettingHour: gymDayCutoffHour,
        minute: 0,
        second: 0,
        of: gymDay
      ) ?? gymDay
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    return start...end.addingTimeInterval(-0.001)
  }

  /// The persisted-log window for one plan day: 04:00 at the start of that
  /// calendar date through the instant before 04:00 on the following date.
  ///
  /// Calendar arithmetic keeps this definition shared by the training screen
  /// and set-ref picker without assuming every local day is exactly 86,400
  /// seconds.
  static func dayRange(
    containing date: Date,
    calendar: Calendar = deviceCalendar
  ) -> ClosedRange<Date> {
    let calendarDayStart = calendar.startOfDay(for: date)
    let start =
      calendar.date(
        bySettingHour: gymDayCutoffHour,
        minute: 0,
        second: 0,
        of: calendarDayStart
      ) ?? calendarDayStart
    let nextStart = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    return start...nextStart.addingTimeInterval(-0.001)
  }

}
