import Foundation

/// Opt-in fixtures only. The default Demo seed and stored data remain unchanged.
enum TrainingStripDemoScenario {
  static var current: Int? {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--spec086-behind123") { return 123 }
    if arguments.contains("--spec086-behind") { return 18 }
    if arguments.contains("--spec086-normal") { return 0 }
    return nil
  }

  static func startDate(today: Date, calendar: Calendar, daysBehind: Int) -> Date {
    let gymDay = WorkoutDatePolicy.gymDayToday(now: today, calendar: calendar)
    let anchor =
      PlanCalendarDayIdentity.planDate(matching: gymDay, selectedCalendar: calendar)
      ?? gymDay
    return PlanCalendarDayIdentity.utcCalendar.date(
      byAdding: .day, value: -(daysBehind + 4), to: anchor) ?? anchor
  }

  static func shiftedDate(_ date: Date, offset: Int) -> Date? {
    guard current != nil, offset == 3,
      ProcessInfo.processInfo.arguments.contains("--spec086-shift")
    else { return nil }
    return PlanCalendarDayIdentity.utcCalendar.date(byAdding: .day, value: 5, to: date)
  }

  static func note(_ original: String?) -> String? {
    guard ProcessInfo.processInfo.arguments.contains("--spec086-long-note"),
      let original
    else { return original }
    var note = original
    guard !original.isEmpty else { return original }
    while note.count < 200 { note += " " + original }
    return note
  }
}
