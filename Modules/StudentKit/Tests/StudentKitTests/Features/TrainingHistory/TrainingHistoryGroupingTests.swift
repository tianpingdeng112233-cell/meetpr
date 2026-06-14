import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct TrainingHistoryGroupingTests {
  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    return calendar
  }

  private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    utcCalendar().date(from: DateComponents(year: year, month: month, day: dayOfMonth)) ?? Date()
  }

  private func planDay(_ date: Date) -> StudentPlanDay {
    StudentPlanDay(id: UUID(), date: date, exercises: [])
  }

  @Test func groupsTrainingDaysByPlanWeekNotByIndex() {
    let start = day(2026, 6, 1)
    // 2 training days in week 1, 1 in week 2, 1 in week 3 — index chunking by 7
    // would lump all four together; week bucketing must split them.
    let days = [
      planDay(day(2026, 6, 1)),
      planDay(day(2026, 6, 3)),
      planDay(day(2026, 6, 9)),
      planDay(day(2026, 6, 17)),
    ]
    let weeks = TrainingHistoryViewModel.groupByWeek(days, startDate: start)
    #expect(weeks.map(\.id) == [1, 2, 3])
    #expect(weeks[0].days.count == 2)
    #expect(weeks[1].days.count == 1)
    #expect(weeks[2].days.count == 1)
  }

  @Test func nilStartDateFallsBackToSingleWeek() {
    let days = [planDay(day(2026, 6, 1)), planDay(day(2026, 6, 9))]
    let weeks = TrainingHistoryViewModel.groupByWeek(days, startDate: nil)
    #expect(weeks.count == 1)
    #expect(weeks[0].id == 1)
    #expect(weeks[0].days.count == 2)
  }

  @Test func emptyDaysReturnsNoWeeks() {
    #expect(TrainingHistoryViewModel.groupByWeek([], startDate: day(2026, 6, 1)).isEmpty)
    #expect(TrainingHistoryViewModel.groupByWeek([], startDate: nil).isEmpty)
  }
}
