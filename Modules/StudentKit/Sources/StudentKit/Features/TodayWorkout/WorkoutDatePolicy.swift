import Foundation

/// Gym-day bucketing for log timestamps and same-Shanghai-gym-day completion undo.
/// Sequence editability is cursor-based and must never call this policy.
enum WorkoutDatePolicy {
  /// 04:00 gym-day cutoff applied before resolving a calendar day.
  static let gymDayCutoff: TimeInterval = 4 * 3600

  static var shanghaiCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? calendar.timeZone
    return calendar
  }

  /// The timestamp shifted into its gym-day for calendar bucketing.
  static func gymDayToday(now: Date = Date()) -> Date {
    now.addingTimeInterval(-gymDayCutoff)
  }

  static func gymDayRange(containing timestamp: Date) -> ClosedRange<Date> {
    let calendar = shanghaiCalendar
    let gymDay = gymDayToday(now: timestamp)
    let startOfGymDay = calendar.startOfDay(for: gymDay)
    let start =
      calendar.date(byAdding: .second, value: Int(gymDayCutoff), to: startOfGymDay)
      ?? startOfGymDay
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
    calendar: Calendar = .current
  ) -> ClosedRange<Date> {
    let calendarDayStart = calendar.startOfDay(for: date)
    let start =
      calendar.date(
        bySettingHour: 4,
        minute: 0,
        second: 0,
        of: calendarDayStart
      ) ?? calendarDayStart
    let nextStart = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    return start...nextStart.addingTimeInterval(-0.001)
  }

}
