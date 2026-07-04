import Foundation

/// Which browsed training day the student may write to. Only today's session is
/// editable — past days are a read-only record, future days a preview — so a
/// set can't be logged (or the day completed) on a day the student has not
/// trained. Extracted from the view so the gate has a unit-testable seam.
enum WorkoutDatePolicy {
  static func isEditable(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    calendar.isDate(date, inSameDayAs: now)
  }

  static func isPast(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    date < calendar.startOfDay(for: now)
  }
}
