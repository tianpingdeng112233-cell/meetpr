import CoreModels
import Foundation
import Testing

@testable import CoachKit

/// 完成态必须由聚合现场按传入的 calendar 判定,不能在取数时压成 Bool。
///
/// 单独成一个 suite 而不是并进 `CoachWeekOverviewTests`,是为了让「完成态口径」
/// 这条防线独立可读——它挡的是一类曾经真出现过的假绿:列会跟着时区重映射,
/// 完成态却停留在旧日历的结论上(review-loop 2026-07-30)。
@Suite("Coach week overview · completion")
struct CoachWeekOverviewCompletionTests {
  @Test("completion is re-decided per calendar, not frozen at fetch time")
  func completionFollowsTheSuppliedCalendar() throws {
    let shanghai = try calendar(timeZoneID: "Asia/Shanghai")
    let losAngeles = try calendar(timeZoneID: "America/Los_Angeles")
    // 计划日 = 沪时 2026-01-01 09:00(= 洛杉矶 2025-12-31 17:00);
    // 完成日志 = 沪时同日 23:00(= 洛杉矶 2026-01-01 07:00)。
    // 两者在东八区是同一天,在洛杉矶分属两天。
    let planDay = try date(2026, 1, 1, hour: 9, calendar: shanghai)
    let logInstant = try date(2026, 1, 1, hour: 23, calendar: shanghai)
    let trainingDay = CoachWeekOverview.TrainingDay(
      date: planDay,
      completedLogDates: [logInstant]
    )

    let shanghaiProgress = CoachWeekOverview.progress(
      trainingDays: [trainingDay],
      now: planDay,
      calendar: shanghai
    )
    let losAngelesProgress = CoachWeekOverview.progress(
      trainingDays: [trainingDay],
      now: planDay,
      calendar: losAngeles
    )

    #expect(shanghaiProgress == CoachWeekOverview.Progress(completed: 1, planned: 1))
    // 若完成态是取数时用旧日历压成的 Bool,这里会假绿成 completed: 1。
    #expect(losAngelesProgress == CoachWeekOverview.Progress(completed: 0, planned: 1))
  }

  @Test("a log outside the pairing window never counts as completion")
  func farAwayLogDoesNotComplete() throws {
    let shanghai = try calendar(timeZoneID: "Asia/Shanghai")
    let planDay = try date(2026, 1, 1, hour: 9, calendar: shanghai)
    let staleLog = try date(2026, 1, 3, hour: 9, calendar: shanghai)
    let trainingDay = CoachWeekOverview.TrainingDay(
      date: planDay,
      completedLogDates: [staleLog]
    )

    let progress = CoachWeekOverview.progress(
      trainingDays: [trainingDay],
      now: planDay,
      calendar: shanghai
    )

    #expect(progress == CoachWeekOverview.Progress(completed: 0, planned: 1))
  }

  private func calendar(timeZoneID: String) throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
    return calendar
  }

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int,
    calendar: Calendar
  ) throws -> Date {
    try #require(
      calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour)
      )
    )
  }
}
