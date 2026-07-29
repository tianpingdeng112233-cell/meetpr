import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func dashboardCalendarLightsDeviceTodayPlanAcrossUTCBoundary() throws {
  let shanghai = try calendar("Asia/Shanghai")
  let deviceToday = try date(
    2026,
    7,
    29,
    hour: 0,
    minute: 30,
    calendar: shanghai
  )
  let plan = StudentDemoSeed.makePlanView(
    today: deviceToday,
    todayOffset: 0,
    selectedCalendar: shanghai
  )

  let cells = DashboardTodayPresentation.calendarCells(
    days: plan.days,
    logs: [],
    selectedDate: deviceToday,
    today: deviceToday,
    selectedCalendar: shanghai
  )

  let todayCell = try #require(cells.first { $0.isSelected })
  let dayOne = try #require(plan.days.first)
  #expect(!todayCell.families.isEmpty)
  #expect(!todayCell.isInProgress)
  #expect(
    PlanCalendarDayIdentity.matches(
      planDate: dayOne.date,
      selectedDate: todayCell.date,
      selectedCalendar: shanghai
    )
  )
}

@Test func dashboardCalendarUsesYellowOnlyForInProgressSession() throws {
  let utc = try calendar("UTC")
  let today = try date(2026, 7, 28, calendar: utc)
  let plan = StudentDemoSeed.makePlanView(
    today: today,
    todayOffset: 0,
    selectedCalendar: utc
  )
  let day = try #require(plan.days.first)
  let exercise = try #require(day.exercises.first)
  let set = try #require(exercise.prescribedSets.first)
  let log = StudentSetLog(
    id: UUID(),
    studentID: StudentDemoSeed.studentID,
    planExerciseID: exercise.id,
    exerciseID: exercise.exercise.id,
    setIndex: set.setIndex,
    loggedAt: today,
    weightKg: set.weightKg ?? 0,
    reps: set.reps ?? 0,
    rpe: set.rpe,
    completed: true
  )

  let cells = DashboardTodayPresentation.calendarCells(
    days: plan.days,
    logs: [log],
    selectedDate: today,
    today: today,
    selectedCalendar: utc
  )

  let todayCell = try #require(cells.first { $0.isSelected })
  #expect(todayCell.isInProgress)
}

private func calendar(_ identifier: String) throws -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: identifier))
  return calendar
}

private func date(
  _ year: Int,
  _ month: Int,
  _ day: Int,
  hour: Int = 0,
  minute: Int = 0,
  calendar: Calendar
) throws -> Date {
  try #require(
    calendar.date(
      from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
      )
    )
  )
}
