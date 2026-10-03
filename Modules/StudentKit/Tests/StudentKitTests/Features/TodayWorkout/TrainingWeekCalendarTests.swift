import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingWeekCalendarTests {
  @Test func fourTrainingDaysIncludeRestDaysAtTheirCalendarPositions() throws {
    let days = try calendarDays(["2026-10-05", "2026-10-07", "2026-10-09", "2026-10-10"])
    let page = TrainingSequenceLayout.page(days: days.reversed(), selectedDayID: days[2].id)
    let week = try #require(page.visibleWeek)
    let cells = week.calendarCells

    #expect(cells.count == 7)
    #expect(cells.map { $0.trainingDay?.dayNumber } == [1, nil, 2, nil, 3, 4, nil])
    #expect(
      cells.map { $0.trainingDay?.state } == [
        .current, nil, .upcoming, nil,
        .upcoming, .upcoming, nil,
      ])
    #expect(cells.filter { $0.trainingDay?.isSelected == true }.map(\.id) == [cells[4].id])
    #expect(
      cells.map { $0.date.formatted(.iso8601.year().month().day().dateSeparator(.dash)) }
        == [
          "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09",
          "2026-10-10", "2026-10-11",
        ])
  }

  @Test func shiftedRecommendationExtendsCalendarBeyondSevenDays() throws {
    let days = try calendarDays(["2026-10-28", "2026-10-30"])
    let shifted = StudentPlanDay(
      id: days[1].id, weekNumber: 1, dayOfWeek: 2, sortOrder: 0,
      date: days[1].scheduledDate,
      shiftedToDate: try Date("2026-11-05T00:00:00Z", strategy: .iso8601), exercises: [])
    let page = TrainingSequenceLayout.page(days: [days[0], shifted], selectedDayID: shifted.id)
    let cells = try #require(page.visibleWeek).calendarCells

    #expect(cells.count == 9)
    #expect(cells.map { $0.trainingDay?.dayNumber } == [1, nil, nil, nil, nil, nil, nil, nil, 2])
    #expect(cells.last?.date == shifted.date)
    #expect(cells.last?.trainingDay?.isSelected == true)
    #expect(page.currentSelection == days[0].id)
  }

  @Test func sevenTrainingDaysHaveNoRestCellsAndKeepCompletedProgress() throws {
    let days = try calendarDays([
      "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02",
      "2027-01-03", "2027-01-04",
    ]).map { $0.replacingCompletion(completedAt: $0.date, source: "manual") }
    let page = TrainingSequenceLayout.page(days: days, selectedDayID: nil)
    let week = try #require(page.visibleWeek)
    let cells = week.calendarCells

    #expect(cells.count == 7)
    #expect(cells.map { $0.trainingDay?.dayNumber } == [1, 2, 3, 4, 5, 6, 7])
    #expect(cells.allSatisfy { $0.trainingDay?.state == .completed })
    #expect(cells.map(\.date) == days.map(\.date))
    #expect(cells.last?.trainingDay?.isSelected == true)
    #expect(week.completedCount == 7)
    #expect(!page.showsBackToToday)
  }

  private func calendarDays(_ dates: [String]) throws -> [StudentPlanDay] {
    try dates.enumerated().map { index, date in
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: index + 1, sortOrder: 0,
        date: try Date(date + "T00:00:00Z", strategy: .iso8601), exercises: [])
    }
  }
}
