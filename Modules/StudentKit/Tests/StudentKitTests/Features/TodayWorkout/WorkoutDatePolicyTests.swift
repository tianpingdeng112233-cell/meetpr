import Foundation
import Testing

@testable import StudentKit

/// The 04:00 policy only buckets logs and the device-local undo window. Sequence
/// editability is intentionally tested elsewhere from completion cursor state.
@Suite struct WorkoutDatePolicyTests {
  private func calendar(timeZoneIdentifier: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
    return calendar
  }

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 12,
    minute: Int = 0,
    calendar: Calendar
  ) throws -> Date {
    try #require(
      calendar.date(
        from: DateComponents(
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute
        )
      )
    )
  }

  private func backendTrainingDay(now: Date, calendar: Calendar) -> Date {
    let localDay = calendar.startOfDay(for: now)
    guard calendar.component(.hour, from: now) < 4 else { return localDay }
    return calendar.date(byAdding: .day, value: -1, to: localDay) ?? localDay
  }

  @Test func sharedDayRangeSpansFourAMToTheNextFourAM() throws {
    let calendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
    let planDay = try date(2026, 7, 4, calendar: calendar)
    let range = WorkoutDatePolicy.dayRange(containing: planDay, calendar: calendar)

    #expect(range.contains(try date(2026, 7, 4, hour: 4, calendar: calendar)))
    #expect(range.contains(try date(2026, 7, 5, hour: 0, calendar: calendar)))
    #expect(range.contains(try date(2026, 7, 5, hour: 3, minute: 59, calendar: calendar)))
    #expect(!range.contains(try date(2026, 7, 4, hour: 3, minute: 59, calendar: calendar)))
    #expect(!range.contains(try date(2026, 7, 5, hour: 4, calendar: calendar)))
    #expect(
      TodayWorkoutViewModel.dayRange(containing: planDay, calendar: calendar)
        == range
    )
  }

  @Test(arguments: Array(0...23))
  func shanghaiGymDayMatchesLegacyElapsedFourHourBucketing(hour: Int) throws {
    let calendar = try calendar(timeZoneIdentifier: "Asia/Shanghai")
    let now = try date(2026, 8, 20, hour: hour, minute: 31, calendar: calendar)
    let legacyGymDay = calendar.startOfDay(for: now.addingTimeInterval(-4 * 3_600))

    #expect(WorkoutDatePolicy.gymDayToday(now: now, calendar: calendar) == legacyGymDay)
  }

  @Test func wallClockCutoffChangesGymDayAtExactlyFourAM() throws {
    let calendar = try calendar(timeZoneIdentifier: "America/New_York")
    let beforeCutoff = try date(2026, 8, 20, hour: 3, minute: 59, calendar: calendar)
    let atCutoff = try date(2026, 8, 20, hour: 4, calendar: calendar)
    let previousDay = try date(2026, 8, 19, hour: 0, calendar: calendar)
    let currentDay = try date(2026, 8, 20, hour: 0, calendar: calendar)

    #expect(
      WorkoutDatePolicy.gymDayToday(now: beforeCutoff, calendar: calendar)
        == previousDay
    )
    #expect(
      WorkoutDatePolicy.gymDayToday(now: atCutoff, calendar: calendar)
        == currentDay
    )
  }

  @Test func newYorkGymDayMatchesBackendWallClockSemantics() throws {
    let calendar = try calendar(timeZoneIdentifier: "America/New_York")
    let eveningCheckIn = try date(2026, 8, 20, hour: 21, calendar: calendar)
    let expectedDay = try date(2026, 8, 20, hour: 0, calendar: calendar)

    #expect(
      WorkoutDatePolicy.gymDayToday(now: eveningCheckIn, calendar: calendar)
        == backendTrainingDay(now: eveningCheckIn, calendar: calendar)
    )
    #expect(
      WorkoutDatePolicy.gymDayToday(now: eveningCheckIn, calendar: calendar)
        == expectedDay
    )
  }

  @Test func springDSTUsesFourAMWallClockInsteadOfFourElapsedHours() throws {
    let calendar = try calendar(timeZoneIdentifier: "America/New_York")
    let afterCutoff = try date(2026, 3, 8, hour: 4, minute: 30, calendar: calendar)
    let wallClockGymDay = WorkoutDatePolicy.gymDayToday(
      now: afterCutoff,
      calendar: calendar
    )
    let elapsedHoursGymDay = calendar.startOfDay(
      for: afterCutoff.addingTimeInterval(-4 * 3_600)
    )
    let expectedWallClockDay = try date(2026, 3, 8, hour: 0, calendar: calendar)
    let expectedElapsedHoursDay = try date(2026, 3, 7, hour: 0, calendar: calendar)

    #expect(wallClockGymDay == expectedWallClockDay)
    #expect(elapsedHoursGymDay == expectedElapsedHoursDay)
    #expect(wallClockGymDay != elapsedHoursGymDay)
  }

  @Test func fallDSTUsesFourAMWallClockInsteadOfFourElapsedHours() throws {
    let calendar = try calendar(timeZoneIdentifier: "America/New_York")
    let beforeCutoff = try date(2026, 11, 1, hour: 3, minute: 30, calendar: calendar)
    let wallClockGymDay = WorkoutDatePolicy.gymDayToday(
      now: beforeCutoff,
      calendar: calendar
    )
    let elapsedHoursGymDay = calendar.startOfDay(
      for: beforeCutoff.addingTimeInterval(-4 * 3_600)
    )
    let expectedWallClockDay = try date(2026, 10, 31, hour: 0, calendar: calendar)
    let expectedElapsedHoursDay = try date(2026, 11, 1, hour: 0, calendar: calendar)

    #expect(wallClockGymDay == expectedWallClockDay)
    #expect(elapsedHoursGymDay == expectedElapsedHoursDay)
    #expect(wallClockGymDay != elapsedHoursGymDay)
  }

  @Test func deviceCalendarGymDayRangeRollsAtFourAM() throws {
    let calendar = try calendar(timeZoneIdentifier: "America/New_York")
    let range = WorkoutDatePolicy.gymDayRange(
      containing: try date(2026, 7, 5, hour: 3, minute: 59, calendar: calendar),
      calendar: calendar
    )

    #expect(range.contains(try date(2026, 7, 4, hour: 4, calendar: calendar)))
    #expect(range.contains(try date(2026, 7, 5, hour: 3, minute: 59, calendar: calendar)))
    #expect(!range.contains(try date(2026, 7, 5, hour: 4, calendar: calendar)))
  }
}
