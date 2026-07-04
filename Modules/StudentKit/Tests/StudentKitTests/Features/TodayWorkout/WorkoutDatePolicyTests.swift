import Foundation
import Testing

@testable import StudentKit

/// The read-only gate: only today is writable; past = record, future = preview.
@Suite struct WorkoutDatePolicyTests {
  private let calendar = Calendar(identifier: .gregorian)

  private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
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
}
