import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingWeekPresentationTests {
  @Test func cellsUseDatesOrBehindAndAccessibleSequenceCodes() throws {
    let today = try Date("2026-09-23T00:00:00Z", strategy: .iso8601)
    let date = try Date("2026-09-21T00:00:00Z", strategy: .iso8601)
    let day = StudentPlanDay(
      id: UUID(), weekNumber: 3, dayOfWeek: 1, sortOrder: 0,
      date: date, exercises: [])
    let item = TrainingSequenceDay(day: day, dayNumber: 1, state: .current, isSelected: true)
    let behind = TrainingWeekCellPresentation(
      cell: .training(item), today: today,
      locale: Locale(identifier: "en"), calendar: PlanCalendarDayIdentity.utcCalendar)
    #expect(behind.lines == ["Mon", "Behind"])
    #expect(behind.accessibilityLabel == "W3D1, Mon, behind schedule")
    #expect(behind.isBehind)
    let onTime = TrainingWeekCellPresentation(
      cell: .training(item), today: date,
      locale: Locale(identifier: "en"), calendar: PlanCalendarDayIdentity.utcCalendar)
    #expect(onTime.lines == ["Mon", "9/21"])
    #expect(onTime.accessibilityLabel == "W3D1, Mon 9/21")
    let completed = TrainingSequenceDay(
      day: day.replacingCompletion(completedAt: today, source: "manual"),
      dayNumber: 1, state: .completed, isSelected: false)
    #expect(
      TrainingWeekCellPresentation(
        cell: .training(completed), today: today,
        locale: Locale(identifier: "en")
      ).lines == ["Mon", "9/21"])
    let rest = TrainingWeekCellPresentation(
      cell: .rest(date), today: today,
      locale: Locale(identifier: "en"))
    #expect(rest.lines == ["Mon", "Rest"])
    #expect(rest.accessibilityLabel == "Mon, rest day")
  }

  @Test func weekStatusUsesLocalizedPluralOnlyForCurrentWeek() {
    let english = Locale(identifier: "en")
    let chinese = Locale(identifier: "zh-Hans")
    #expect(
      TrainingWeekStatusPresentation(state: .current, daysBehind: 0, locale: english).text
        == "Current week")
    #expect(
      TrainingWeekStatusPresentation(state: .current, daysBehind: 1, locale: english).text
        == "1 day behind")
    #expect(
      TrainingWeekStatusPresentation(state: .current, daysBehind: 18, locale: english).text
        == "18 days behind")
    #expect(
      TrainingWeekStatusPresentation(state: .current, daysBehind: 123, locale: english)
        .accessibilityLabel == "123 days behind schedule")
    #expect(
      TrainingWeekStatusPresentation(state: .current, daysBehind: 18, locale: chinese).text
        == "已落后 18 天")
    #expect(
      TrainingWeekStatusPresentation(state: .upcoming, daysBehind: 18, locale: english).text
        == "Upcoming")
    #expect(
      TrainingWeekStatusPresentation(state: .completed, daysBehind: 18, locale: english).text
        == "Completed")
  }
}
