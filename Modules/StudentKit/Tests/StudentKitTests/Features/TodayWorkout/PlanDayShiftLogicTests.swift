import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func proposalCarriesCourseAndCurrentAndShiftedCycleEndDates() throws {
  let today = utcDate(2026, 7, 11)
  let endDate = utcDate(2026, 7, 28)
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 2,
    startDate: utcDate(2026, 7, 1),
    endDate: endDate,
    totalShiftDays: 2,
    days: [
      StudentPlanDay(
        id: UUID(),
        date: today,
        exercises: [testExercise(name: "深蹲")]
      )
    ]
  )

  let proposal = try #require(
    PlanDayShiftLogic.proposal(plan: plan, today: today, calendar: utcCalendar())
  )

  #expect(proposal.courseName == "深蹲")
  #expect(proposal.currentEndDate == utcDate(2026, 7, 30))
  #expect(proposal.shiftedEndDate == utcDate(2026, 7, 31))
  #expect(
    PlanDayShiftLogic.confirmationMessage(for: proposal)
      == "今天的深蹲课改到明天，之后的课依次顺延，本周期结束日变为7月31日"
  )
}

@Test func proposalRequiresTodayToBeATrainingDay() {
  let today = utcDate(2026, 7, 11)
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: today,
    endDate: utcDate(2026, 7, 31),
    days: [StudentPlanDay(id: UUID(), date: today, exercises: [])]
  )

  #expect(PlanDayShiftLogic.proposal(plan: plan, today: today) == nil)
}

@Test func undoWindowUsesUTCCalendarDay() {
  let createdAt = isoDate("2026-07-11T23:30:00Z")

  #expect(
    PlanDayShiftLogic.canUndo(
      latestShiftCreatedAt: createdAt,
      now: isoDate("2026-07-11T00:01:00Z"),
      calendar: utcCalendar()
    )
  )
  #expect(
    !PlanDayShiftLogic.canUndo(
      latestShiftCreatedAt: createdAt,
      now: isoDate("2026-07-12T00:00:00Z"),
      calendar: utcCalendar()
    )
  )
  #expect(
    !PlanDayShiftLogic.canUndo(
      latestShiftCreatedAt: nil,
      now: createdAt,
      calendar: utcCalendar()
    )
  )
}

@Test func cumulativeShiftAdviceStartsAtThreeDays() {
  #expect(PlanDayShiftLogic.cumulativeShiftMessage(totalShiftDays: 2) == nil)
  #expect(
    PlanDayShiftLogic.cumulativeShiftMessage(totalShiftDays: 3)
      == "已累计顺延 3 天，建议联系教练调整计划"
  )
  #expect(
    PlanDayShiftLogic.cumulativeShiftMessage(totalShiftDays: 8)
      == "已累计顺延 8 天，建议联系教练调整计划"
  )
}

@Test(arguments: [
  (PlanShiftError.planNotActive, "当前计划未生效，暂时不能顺延"),
  (PlanShiftError.onlyToday, "只能顺延今天的训练"),
  (PlanShiftError.alreadyStarted, "今天的训练已经开始，不能顺延或撤销"),
  (PlanShiftError.notPlanStudent, "只有计划所属学员可以顺延"),
  (PlanShiftError.noActiveShift, "当前没有可撤销的顺延"),
  (PlanShiftError.undoWindowPassed, "只能在顺延当天撤销，请联系教练调整计划"),
])
func shiftMachineCodeErrorsHaveSpecificChineseCopy(error: PlanShiftError, message: String) {
  #expect(PlanDayShiftLogic.errorMessage(for: error, operation: .shift) == message)
}

private func testExercise(name: String) -> StudentPlanExercise {
  StudentPlanExercise(
    id: UUID(),
    exercise: Exercise(
      id: UUID(),
      name: name,
      exerciseType: .mainLift,
      mainLiftFamily: .squat,
      isCompetitionLift: true,
      muscleGroups: [.quad],
      equipment: [.barbell],
      movementPattern: [.squat],
      createdAt: .distantPast
    ),
    sequenceIndex: 0,
    prescribedSets: []
  )
}

private func utcCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
  utcCalendar().date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}

private func isoDate(_ value: String) -> Date {
  (try? Date(value, strategy: .iso8601)) ?? .distantPast
}
