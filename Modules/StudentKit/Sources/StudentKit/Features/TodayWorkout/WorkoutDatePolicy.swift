import Foundation

/// Which browsed training day the student may write to. Only today's session is
/// editable — past days are a read-only record, future days a preview — so a
/// set can't be logged (or the day completed) on a day the student has not
/// trained. Extracted from the view so the gate has a unit-testable seam.
///
/// "Today" uses the gym-day cutoff: the day rolls over at 04:00, not midnight,
/// so a session that crosses 00:00 stays editable until 4 AM (and the next
/// calendar day does not open for writing before 04:00). Counterpart of the
/// backend's spec 017 default-`logged_date` cutoff (04:00 Asia/Shanghai).
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

  /// A timestamp that falls inside the current gym-day — use it wherever a
  /// "today" anchor seeds day selection (initial `selectedDate`, jump-to-today)
  /// so navigation lands on the day that is actually editable.
  static func gymDayToday(now: Date = Date()) -> Date {
    now.addingTimeInterval(-gymDayCutoff)
  }

  static func isEditable(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    calendar.isDate(date, inSameDayAs: gymDayToday(now: now))
  }

  static func isPast(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    date < calendar.startOfDay(for: gymDayToday(now: now))
  }
}
