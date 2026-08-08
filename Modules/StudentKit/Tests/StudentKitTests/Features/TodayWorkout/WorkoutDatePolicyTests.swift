import Foundation
import Testing

@testable import StudentKit

/// The 04:00 policy only buckets logs and the Shanghai undo window. Sequence
/// editability is intentionally tested elsewhere from completion cursor state.
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

  @Test func sharedDayRangeSpansFourAMToTheNextFourAM() throws {
    let planDay = try day(2026, 7, 4)
    let range = WorkoutDatePolicy.dayRange(containing: planDay, calendar: calendar)

    #expect(range.contains(try day(2026, 7, 4, hour: 4)))
    #expect(range.contains(try day(2026, 7, 5, hour: 0)))
    #expect(range.contains(try day(2026, 7, 5, hour: 3, minute: 59)))
    #expect(!range.contains(try day(2026, 7, 4, hour: 3, minute: 59)))
    #expect(!range.contains(try day(2026, 7, 5, hour: 4)))
    #expect(
      TodayWorkoutViewModel.dayRange(containing: planDay, calendar: calendar)
        == range
    )
  }

  @Test func shanghaiUndoRangeRollsAtFourAM() throws {
    let range = WorkoutDatePolicy.gymDayRange(
      containing: try day(2026, 7, 5, hour: 3, minute: 59)
    )

    #expect(range.contains(try day(2026, 7, 4, hour: 4)))
    #expect(range.contains(try day(2026, 7, 5, hour: 3, minute: 59)))
    #expect(!range.contains(try day(2026, 7, 5, hour: 4)))
  }
}
