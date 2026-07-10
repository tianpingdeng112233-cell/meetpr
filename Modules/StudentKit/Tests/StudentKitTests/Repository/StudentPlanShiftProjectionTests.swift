import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

// day_of_week is POSITIONAL (canonical per David 2026-07-10): day 1 of week 1 is
// start_date itself, regardless of which weekday start_date falls on. This matches
// plan-web import/rendering and the native coach planner.

@Test func projectionTreatsDayOfWeekAsOrdinalPositionFromStartDate() throws {
  let startDate = utcDate(2026, 7, 8)  // a Wednesday — day 1 must still be 7/8 itself
  let firstDay = PlanDay(
    id: UUID(),
    planID: UUID(),
    dayOfWeek: 1,
    weekNumber: 1,
    sortOrder: 0
  )
  let view = StudentPlanProjection.project(
    tree: tree(startDate: startDate, days: [firstDay]),
    catalog: [],
    weekIndex: 1
  )

  let day = try #require(view.days.first)
  #expect(day.scheduledDate == utcDate(2026, 7, 8))
  #expect(day.date == utcDate(2026, 7, 8))
}

@Test func projectionOffsetsLaterPositionsAndWeeksFromStartDate() throws {
  let planID = UUID()
  let thirdDayWeekTwo = PlanDay(
    id: UUID(),
    planID: planID,
    dayOfWeek: 3,
    weekNumber: 2,
    sortOrder: 0
  )
  let view = StudentPlanProjection.project(
    tree: tree(planID: planID, startDate: utcDate(2026, 7, 8), days: [thirdDayWeekTwo]),
    catalog: [],
    weekIndex: 2
  )

  // start + (2-1)*7 + (3-1) = 7/8 + 9 days = 7/17
  #expect(try #require(view.days.first).date == utcDate(2026, 7, 17))
}

@Test func projectionUsesShiftOverrideAsTheOnlyEffectiveDate() throws {
  let planID = UUID()
  let shifted = PlanDay(
    id: UUID(),
    planID: planID,
    dayOfWeek: 3,
    weekNumber: 1,
    sortOrder: 0,
    shiftedToDate: utcDate(2026, 7, 11)
  )
  let view = StudentPlanProjection.project(
    tree: tree(planID: planID, startDate: utcDate(2026, 7, 8), days: [shifted]),
    catalog: [],
    weekIndex: 1
  )

  let day = try #require(view.days.first)
  #expect(day.scheduledDate == utcDate(2026, 7, 10))  // positional: start + 2
  #expect(day.shiftedToDate == utcDate(2026, 7, 11))
  #expect(day.date == utcDate(2026, 7, 11))
}

private func tree(
  planID: UUID = UUID(),
  startDate: Date,
  days: [PlanDay]
) -> TrainingPlanTree {
  let plan = TrainingPlan(
    id: planID,
    coachID: UUID(),
    traineeID: UUID(),
    name: "日期投影测试",
    startDate: startDate,
    endDate: startDate.addingTimeInterval(27 * 86_400),
    planWeeks: 4,
    source: .coach,
    status: .published,
    createdAt: startDate,
    updatedAt: startDate
  )
  return TrainingPlanTree(plan: plan, days: days, exercises: [], sets: [])
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date.distantPast
}
