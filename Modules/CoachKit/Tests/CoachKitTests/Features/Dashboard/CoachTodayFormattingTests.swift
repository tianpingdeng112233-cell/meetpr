import Foundation
import Testing

@testable import CoachKit

@Suite("Coach today formatting")
struct CoachTodayFormattingTests {
  @Test("formats the mockup month-day and weekday with an explicit calendar")
  func dateTextMatchesMockup() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
    let date = try #require(
      calendar.date(
        from: DateComponents(
          year: 2026,
          month: 7,
          day: 30,
          hour: 12
        )
      )
    )

    #expect(
      CoachTodayFormatting.dateText(
        date,
        calendar: calendar,
        locale: Locale(identifier: "zh_Hans_CN")
      ) == "7月30日 · 星期四"
    )
  }
}
