import Foundation
import Testing

@testable import StudentKit

@Suite struct TodayWorkoutSelectionResolverTests {
  @Test func initialAndJumpSelectionsUseDeviceDayAtHalfPastMidnight() throws {
    var shanghai = Calendar(identifier: .gregorian)
    shanghai.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
    let now = try #require(
      shanghai.date(
        from: DateComponents(
          year: 2026,
          month: 7,
          day: 29,
          hour: 0,
          minute: 30
        )
      )
    )
    let previousDay = try #require(
      shanghai.date(from: DateComponents(year: 2026, month: 7, day: 28))
    )

    let initialSelection = TodayWorkoutSelectionResolver.initialSelection(
      explicitDate: nil,
      now: now,
      calendar: shanghai
    )
    let jumpSelection = try #require(
      TodayWorkoutSelectionResolver.jumpToTodaySelection(
        from: previousDay,
        now: now,
        calendar: shanghai
      )
    )

    #expect(shanghai.component(.day, from: initialSelection) == 29)
    #expect(shanghai.component(.day, from: jumpSelection) == 29)
    #expect(StudentDemoSeed.utcCalendar.component(.day, from: now) == 28)
  }
}
