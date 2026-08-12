import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func dashboardCursorUsesCompletionInsteadOfRecommendedDate() {
  let days = sequenceDays()
  let cursor = DashboardTodayPresentation.cursor(in: days)

  #expect(cursor?.id == days[1].id)
  #expect(DashboardTodayPresentation.code(for: cursor ?? days[0]) == "W1D2")
}

@Test func dashboardProgressUsesOnlyCurrentSequenceWeekAndCrossesWeek() {
  let days = sequenceDays()
  let firstWeek = DashboardTodayPresentation.progressSegments(days: days)
  #expect(firstWeek.map(\.state) == [.done, .current])

  let advanced = days.map { day in
    day.weekNumber == 1
      ? day.replacingCompletion(completedAt: Date(), source: "manual")
      : day
  }
  let secondWeek = DashboardTodayPresentation.progressSegments(days: advanced)
  #expect(secondWeek.map(\.dayNumber) == [1])
  #expect(secondWeek.map(\.state) == [.current])
}

@Test func dashboardHasNoCursorAfterEverySequenceDayCompletes() {
  let completed = sequenceDays().map {
    $0.replacingCompletion(completedAt: Date(), source: "manual")
  }

  #expect(DashboardTodayPresentation.cursor(in: completed) == nil)
  #expect(
    DashboardTodayPresentation.progressSegments(days: completed).allSatisfy {
      $0.state == .done
    })
}

@Test func shiftedProjectionStillDisplaysCoachAuthoredRecommendation() {
  let original = Date(timeIntervalSince1970: 1_800_000_000)
  let shifted = original.addingTimeInterval(5 * 86_400)
  let day = StudentPlanDay(
    id: UUID(), weekNumber: 1, dayOfWeek: 1, date: original,
    shiftedToDate: shifted, exercises: []
  )

  #expect(day.scheduledDate == original)
  #expect(day.date == shifted)
  #expect(day.shiftedToDate == shifted)
}

@Test func dashboardCompletionTodayUsesShanghaiGymDayBoundary() throws {
  let calendar = WorkoutDatePolicy.shanghaiCalendar
  let beforeCutoff = try #require(
    calendar.date(from: DateComponents(year: 2030, month: 1, day: 2, hour: 3, minute: 59))
  )
  let completedAt = beforeCutoff.addingTimeInterval(-60)
  let day = sequenceDays()[0].replacingCompletion(completedAt: completedAt, source: "manual")

  #expect(DashboardTodayPresentation.completedToday(in: [day], now: beforeCutoff)?.id == day.id)
  #expect(
    DashboardTodayPresentation.completedToday(
      in: [day],
      now: beforeCutoff.addingTimeInterval(2 * 60)
    ) == nil
  )
}

// The header always renders the real today (sequence-handoff canon), so the
// label must follow the wall clock across a local midnight — not any plan date.
@Test func headerDateTextFollowsTheWallClockAcrossMidnight() {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

  // 2026-08-12 23:59 CST (Wednesday) vs one minute later (Thursday 08-13).
  let beforeMidnight = Date(timeIntervalSince1970: 1_786_550_340)
  let afterMidnight = beforeMidnight.addingTimeInterval(60)

  #expect(
    DashboardTodayPresentation.headerDateText(beforeMidnight, calendar: calendar)
      == "8月12日 · 星期三"
  )
  #expect(
    DashboardTodayPresentation.headerDateText(afterMidnight, calendar: calendar)
      == "8月13日 · 星期四"
  )
}

@Test func liftSubtitleUsesFullNamesForOneOrTwoLiftsOnly() {
  #expect(DashboardTodayPresentation.liftSubtitle([.deadlift]) == "硬拉日")
  #expect(DashboardTodayPresentation.liftSubtitle([.squat, .bench]) == "深蹲、卧推日")
  #expect(DashboardTodayPresentation.liftSubtitle([.squat, .bench, .deadlift]) == "蹲·推·拉")
}

private func sequenceDays() -> [StudentPlanDay] {
  let start = Date(timeIntervalSince1970: 1_800_000_000)
  return [
    StudentPlanDay(
      id: UUID(), weekNumber: 1, dayOfWeek: 1, sortOrder: 0, date: start,
      completedAt: start, completionSource: "auto", exercises: []
    ),
    StudentPlanDay(
      id: UUID(), weekNumber: 1, dayOfWeek: 2, sortOrder: 0,
      date: start.addingTimeInterval(86_400), exercises: []
    ),
    StudentPlanDay(
      id: UUID(), weekNumber: 2, dayOfWeek: 1, sortOrder: 0,
      date: start.addingTimeInterval(7 * 86_400), exercises: []
    ),
  ]
}
