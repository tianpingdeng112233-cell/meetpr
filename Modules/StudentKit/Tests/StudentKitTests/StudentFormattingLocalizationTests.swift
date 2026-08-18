import CoreModels
import Foundation
import Testing

@testable import StudentKit

private let simplifiedChinese = Locale(identifier: "zh_CN")

@Test func localizedDateFormatsPreserveSimplifiedChineseOutput() throws {
  let date = try #require(
    PlanCalendarDayIdentity.utcCalendar.date(
      from: DateComponents(year: 2030, month: 8, day: 18, hour: 13, minute: 5)
    )
  )

  #expect(StudentFormatting.dayMonth(date, locale: simplifiedChinese, timeZone: .gmt) == "8月18日")
  #expect(StudentFormatting.weekday(date, locale: simplifiedChinese, timeZone: .gmt) == "星期日")
  #expect(StudentFormatting.time(date, locale: simplifiedChinese, timeZone: .gmt) == "13:05")
  #expect(StudentFormatting.monthDay(date, locale: simplifiedChinese, timeZone: .gmt) == "8月18日")
  #expect(
    StudentFormatting.numericMonthDay(date, locale: simplifiedChinese, timeZone: .gmt) == "8/18")
}

@MainActor
@Test func completionDatePreservesSimplifiedChineseOutput() throws {
  let date = try #require(
    PlanCalendarDayIdentity.utcCalendar.date(
      from: DateComponents(year: 2030, month: 8, day: 18, hour: 12)
    )
  )
  let day = StudentPlanDay(id: UUID(), date: date, exercises: [])
  let presentation = WorkoutCompletionPresentation(
    day: day,
    drafts: [],
    references: [:],
    weekCode: "W1D1",
    coachName: nil,
    locale: simplifiedChinese
  )

  #expect(presentation.dateSubtitle == "8/18 · 星期日 · W1D1")
}
