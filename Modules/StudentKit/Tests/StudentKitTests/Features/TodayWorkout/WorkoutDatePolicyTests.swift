import Foundation
import Testing

@testable import StudentKit

/// The read-only gate: only today is writable; past = record, future = preview.
/// "Today" rolls at the 04:00 gym-day cutoff. Pinned to Asia/Shanghai — the
/// domestic-beta reference zone the backend cutoff also uses (DST-free, so the
/// fixed -4h shift is exact; DST-zone drift is a documented accepted trade-off).
@Suite struct WorkoutDatePolicyTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
    return calendar
  }()

  private func day(
    _ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0
  ) throws -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.timeZone = calendar.timeZone
    return try #require(calendar.date(from: comps))
  }

  @Test func todayIsEditable() throws {
    let now = try day(2026, 7, 4, hour: 9)
    let laterToday = try day(2026, 7, 4, hour: 22)
    #expect(WorkoutDatePolicy.isEditable(laterToday, now: now, calendar: calendar))
  }

  @Test func pastAndFutureAreNotEditable() throws {
    let now = try day(2026, 7, 4)
    let yesterday = try day(2026, 7, 3)
    let tomorrow = try day(2026, 7, 5)
    #expect(!WorkoutDatePolicy.isEditable(yesterday, now: now, calendar: calendar))
    #expect(!WorkoutDatePolicy.isEditable(tomorrow, now: now, calendar: calendar))
  }

  @Test func pastClassificationDrivesNoticeCopy() throws {
    let now = try day(2026, 7, 4)
    let yesterday = try day(2026, 7, 3)
    let tomorrow = try day(2026, 7, 5)
    #expect(WorkoutDatePolicy.isPast(yesterday, now: now, calendar: calendar))
    #expect(!WorkoutDatePolicy.isPast(tomorrow, now: now, calendar: calendar))
  }

  // MARK: - Gym-day cutoff (day rolls at 04:00, not midnight)

  @Test func yesterdaySessionStaysEditableThroughEarlyMorning() throws {
    let trainingDay = try day(2026, 7, 4)
    // 23:59 same day — plainly editable.
    #expect(
      WorkoutDatePolicy.isEditable(
        trainingDay, now: try day(2026, 7, 4, hour: 23, minute: 59), calendar: calendar))
    // 00:00 and 03:59 next morning — still the same gym-day, stays editable.
    #expect(
      WorkoutDatePolicy.isEditable(
        trainingDay, now: try day(2026, 7, 5, hour: 0, minute: 0), calendar: calendar))
    #expect(
      WorkoutDatePolicy.isEditable(
        trainingDay, now: try day(2026, 7, 5, hour: 3, minute: 59), calendar: calendar))
    // 04:00 — gym-day rolls over, yesterday becomes a read-only record.
    #expect(
      !WorkoutDatePolicy.isEditable(
        trainingDay, now: try day(2026, 7, 5, hour: 4, minute: 0), calendar: calendar))
  }

  @Test func calendarDayIsNotEditableBeforeItsGymDayStarts() throws {
    let nextDay = try day(2026, 7, 5)
    // At 00:30 the calendar already says July 5, but the gym-day is still
    // July 4 — July 5's session opens for writing at 04:00.
    #expect(
      !WorkoutDatePolicy.isEditable(
        nextDay, now: try day(2026, 7, 5, hour: 0, minute: 30), calendar: calendar))
    #expect(
      WorkoutDatePolicy.isEditable(
        nextDay, now: try day(2026, 7, 5, hour: 4, minute: 0), calendar: calendar))
  }

  @Test func earlyMorningCalendarDayIsNeitherEditableNorPast() throws {
    // The full partition for the 00:00–03:59 window: the new calendar day is
    // not editable yet AND not past — it renders as a future-day preview
    // ("未到训练日"), never as an editable session or a past record.
    let calendarToday = try day(2026, 7, 5)
    let earlyMorning = try day(2026, 7, 5, hour: 0, minute: 30)
    #expect(!WorkoutDatePolicy.isEditable(calendarToday, now: earlyMorning, calendar: calendar))
    #expect(!WorkoutDatePolicy.isPast(calendarToday, now: earlyMorning, calendar: calendar))
  }

  @Test func gymDayTodayAnchorsSelectionToTheEditableDay() throws {
    // Seeding selectedDate with gymDayToday lands on the editable day both
    // mid-day and inside the early-morning window.
    let midDay = try day(2026, 7, 4, hour: 14)
    #expect(
      WorkoutDatePolicy.isEditable(
        WorkoutDatePolicy.gymDayToday(now: midDay), now: midDay, calendar: calendar))
    let earlyMorning = try day(2026, 7, 5, hour: 0, minute: 30)
    let anchor = WorkoutDatePolicy.gymDayToday(now: earlyMorning)
    #expect(WorkoutDatePolicy.isEditable(anchor, now: earlyMorning, calendar: calendar))
    #expect(calendar.isDate(anchor, inSameDayAs: try day(2026, 7, 4)))
  }

  @Test func pastClassificationFollowsGymDayAcrossMidnightAndMonthEnd() throws {
    // At 00:30 July 5 the gym-day is July 4: July 4 is not yet past.
    #expect(
      !WorkoutDatePolicy.isPast(
        try day(2026, 7, 4), now: try day(2026, 7, 5, hour: 0, minute: 30), calendar: calendar))
    // At 04:00 it is.
    #expect(
      WorkoutDatePolicy.isPast(
        try day(2026, 7, 4), now: try day(2026, 7, 5, hour: 4, minute: 0), calendar: calendar))
    // Month boundary: 00:30 on Aug 1 still belongs to the July 31 gym-day.
    #expect(
      WorkoutDatePolicy.isEditable(
        try day(2026, 7, 31), now: try day(2026, 8, 1, hour: 0, minute: 30), calendar: calendar))
    // Year boundary: 03:59 on Jan 1 still belongs to the Dec 31 gym-day.
    #expect(
      WorkoutDatePolicy.isEditable(
        try day(2026, 12, 31), now: try day(2027, 1, 1, hour: 3, minute: 59), calendar: calendar))
  }
}
