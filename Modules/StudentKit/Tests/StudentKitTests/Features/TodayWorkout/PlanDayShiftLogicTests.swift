import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func nextRestDateFindsTomorrowWithinPlanWeek() throws {
  let start = utcDate(2026, 7, 8)
  let today = start
  let occupied = [
    StudentPlanDay(id: UUID(), date: today, exercises: []),
    StudentPlanDay(id: UUID(), date: utcDate(2026, 7, 10), exercises: []),
  ]

  let target = PlanDayShiftLogic.nextRestDate(
    after: today,
    occupiedBy: occupied,
    planStartDate: start,
    weekIndex: 1,
    calendar: utcCalendar()
  )

  #expect(target == utcDate(2026, 7, 9))
  #expect(
    PlanDayShiftLogic.targetLabel(
      target: try #require(target),
      after: today,
      calendar: utcCalendar()
    ) == "延到明天"
  )
}

@Test func nextRestDateStopsAtPlanWeekBoundary() {
  let start = utcDate(2026, 7, 8)
  let occupied = (0..<7).map { offset in
    StudentPlanDay(
      id: UUID(),
      date: start.addingTimeInterval(Double(offset) * 86_400),
      exercises: []
    )
  }

  let target = PlanDayShiftLogic.nextRestDate(
    after: start,
    occupiedBy: occupied,
    planStartDate: start,
    weekIndex: 1,
    calendar: utcCalendar()
  )

  #expect(target == nil)
}

@Test func nextRestDateUsesEffectiveShiftedDatesAsOccupied() {
  let start = utcDate(2026, 7, 8)
  let shifted = StudentPlanDay(
    id: UUID(),
    date: utcDate(2026, 7, 9),
    shiftedToDate: utcDate(2026, 7, 10),
    exercises: []
  )

  let target = PlanDayShiftLogic.nextRestDate(
    after: start,
    occupiedBy: [shifted],
    planStartDate: start,
    weekIndex: 1,
    calendar: utcCalendar()
  )

  #expect(target == utcDate(2026, 7, 9))
}

@Test(arguments: [
  (PlanDayShiftError.planNotActive, "当前计划未生效，暂时不能顺延"),
  (PlanDayShiftError.onlyToday, "只能顺延今天的训练；顺延后如需调整，请先撤销"),
  (PlanDayShiftError.dayHasLogs, "这天已有训练记录，不能顺延或撤销"),
  (PlanDayShiftError.targetNotRestDay, "目标日期已不是本周休息日，请刷新计划后重试"),
])
func shiftMachineCodeErrorsHaveSpecificChineseCopy(error: PlanDayShiftError, message: String) {
  #expect(PlanDayShiftLogic.errorMessage(for: error, operation: .shift) == message)
}

private func utcCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
  utcCalendar().date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}
