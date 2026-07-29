import Foundation

/// Which browsed training day the student may write to. Only today's session is
/// editable — past days are a read-only record, future days a preview — so a
/// set can't be logged (or the day completed) on a day the student has not
/// trained. Extracted from the view so the gate has a unit-testable seam.
///
/// Write eligibility uses the gym-day cutoff: the day rolls over at 04:00, not
/// midnight, so a session that crosses 00:00 stays editable until 4 AM (and the
/// next calendar day does not open for writing before 04:00). Calendar
/// selection and the visible "today" identity still use the device day through
/// `PlanCalendarDayIdentity`. Counterpart of the backend's spec 017
/// default-`logged_date` cutoff (04:00 Asia/Shanghai).
///
/// Trade-offs, accepted deliberately (review 2026-07-14):
/// - The shift is a fixed -4h on the wall clock in the *device* calendar. In
///   DST-free zones (all of China) this matches the backend exactly. On a DST
///   transition day the local rollover drifts by ±1h, and a device travelling
///   outside Asia/Shanghai sees its local 4 AM, not the server's — both are
///   accepted for the domestic beta; revisit with the overseas wave.
/// - Callers read this at SwiftUI render time; there is no clock-driven
///   re-render at exactly 04:00. A view left open across the cutoff keeps its
///   last verdict until the next interaction re-renders it — an in-flight set
///   entry is allowed to finish naturally.
enum WorkoutDatePolicy {
  /// 04:00 gym-day cutoff, as a fixed shift applied to the wall clock before
  /// resolving the calendar day.
  static let gymDayCutoff: TimeInterval = 4 * 3600

  /// A timestamp that falls inside the current gym-day, used only for write
  /// eligibility. It is not the calendar's visible "today" anchor.
  static func gymDayToday(now: Date = Date()) -> Date {
    now.addingTimeInterval(-gymDayCutoff)
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

  static func isEditable(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    calendar.isDate(date, inSameDayAs: gymDayToday(now: now))
  }

  static func isPast(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    date < calendar.startOfDay(for: gymDayToday(now: now))
  }
}
