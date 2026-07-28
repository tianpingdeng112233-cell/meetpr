import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func dashboardWeekCodeCountsTrainingDaysThroughFriday() throws {
  let calendar = try dashboardCalendar("UTC")
  let plan = StudentDemoSeed.makePlanView(
    today: try dashboardDate(2026, 7, 24, calendar: calendar)
  )
  let friday = plan.days[4].date

  #expect(
    DashboardTodayPresentation.weekCode(
      weekIndex: plan.weekIndex,
      selectedDate: friday,
      days: plan.days,
      selectedCalendar: calendar
    ) == "W1D4"
  )
}

@Test func dashboardWeekCodeCountsSundayWhenItIsATrainingDay() throws {
  let calendar = try dashboardCalendar("UTC")
  let monday = try dashboardDate(2026, 7, 20, calendar: calendar)
  let sunday = try dashboardDate(2026, 7, 26, calendar: calendar)
  let trainingDays = [
    dashboardPlanDay(on: monday, hasTraining: true),
    dashboardPlanDay(on: sunday, hasTraining: true),
  ]

  #expect(
    DashboardTodayPresentation.weekCode(
      weekIndex: 1,
      selectedDate: sunday,
      days: trainingDays,
      selectedCalendar: calendar
    ) == "W1D2"
  )
}

@Test func dashboardWeekCodeUsesWeekOnlyCapsuleOnRestDay() throws {
  let calendar = try dashboardCalendar("UTC")
  let monday = try dashboardDate(2026, 7, 20, calendar: calendar)
  let tuesday = try dashboardDate(2026, 7, 21, calendar: calendar)
  let days = [
    dashboardPlanDay(on: monday, hasTraining: true),
    dashboardPlanDay(on: tuesday, hasTraining: false),
  ]

  #expect(
    DashboardTodayPresentation.weekCode(
      weekIndex: 1,
      selectedDate: tuesday,
      days: days,
      selectedCalendar: calendar
    ) == "W1"
  )
}

@Test func dashboardPlanDayMatchesUTCProjectionToSelectedCalendarComponents() throws {
  let utc = try dashboardCalendar("UTC")
  let shanghai = try dashboardCalendar("Asia/Shanghai")
  let planDate = try dashboardDate(2026, 7, 24, calendar: utc)
  let selectedDate = try dashboardDate(2026, 7, 24, calendar: shanghai)
  let day = StudentPlanDay(id: UUID(), date: planDate, exercises: [])

  #expect(
    DashboardTodayPresentation.planDay(
      on: selectedDate,
      in: [day],
      selectedCalendar: shanghai
    )?.id == day.id
  )
}

@Test func shanghaiMidnightPageShowsLocalDayButShiftEntryHides() throws {
  let utc = try dashboardCalendar("UTC")
  let shanghai = try dashboardCalendar("Asia/Shanghai")
  let shanghaiMidnight = try dashboardDate(
    2026,
    7,
    25,
    hour: 0,
    minute: 30,
    calendar: shanghai
  )
  let localPlanDate = try dashboardDate(2026, 7, 25, calendar: utc)
  let previousUTCDate = try dashboardDate(2026, 7, 24, calendar: utc)
  let localDay = dashboardPlanDay(on: localPlanDate, hasTraining: true, exerciseName: "卧推")
  let previousDay = dashboardPlanDay(
    on: previousUTCDate,
    hasTraining: true,
    exerciseName: "硬拉"
  )

  // The page resolves the *local* July 25 day (device calendar)…
  #expect(
    DashboardTodayPresentation.planDay(
      on: shanghaiMidnight,
      in: [previousDay, localDay],
      selectedCalendar: shanghai
    )?.id == localDay.id
  )
  // …but the UTC-anchored shift mutation would target July 24, so the shift
  // entry hides during the divergence window instead of proposing yesterday.
  #expect(
    DashboardTodayPresentation.shiftTargetsSelectedDay(localDay, now: shanghaiMidnight)
      == false
  )
  // Past 08:00 the two days agree again and the entry may show.
  let shanghaiNoon = try dashboardDate(2026, 7, 25, hour: 12, minute: 0, calendar: shanghai)
  #expect(
    DashboardTodayPresentation.shiftTargetsSelectedDay(localDay, now: shanghaiNoon) == true
  )
  // The proposal itself resolves through UTC — the mutation's contract.
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: previousUTCDate,
    endDate: localPlanDate,
    days: [previousDay, localDay]
  )
  #expect(
    PlanDayShiftLogic.proposal(plan: plan, today: shanghaiMidnight)?.courseName
      == previousDay.exercises.first?.exercise.name
  )
}

@Test func dashboardUTCWeekKeepsLateSundayInTheCurrentWeek() throws {
  let utc = try dashboardCalendar("UTC")
  let lateSunday = try dashboardDate(
    2026,
    7,
    26,
    hour: 23,
    minute: 30,
    calendar: utc
  )
  let weekDates = DashboardTodayPresentation.weekDates(
    containing: lateSunday,
    calendar: PlanCalendarDayIdentity.utcCalendar
  )

  #expect(weekDates.count == 7)
  #expect(
    PlanCalendarDayIdentity.isSameUTCDate(
      try #require(weekDates.last),
      try dashboardDate(2026, 7, 26, calendar: utc)
    )
  )
}

@Test func dashboardWeekBarsUseDoneCurrentUpcomingStates() {
  let plan = StudentDemoSeed.makePlanView()
  let today = plan.days[4].date

  #expect(
    DashboardTodayPresentation.progressSegments(
      days: plan.days,
      logs: [],
      today: today,
      selectedCalendar: StudentDemoSeed.utcCalendar
    ).map(\.state) == [.done, .done, .done, .current]
  )
}

@Test func dashboardRestDayFindsNextTrainingDate() {
  let plan = StudentDemoSeed.makePlanView()
  let restDay = plan.days[2].date

  #expect(
    DashboardTodayPresentation.nextTrainingDate(
      after: restDay,
      days: plan.days,
      selectedCalendar: StudentDemoSeed.utcCalendar
    ) == plan.days[3].date
  )
}

@Test func dashboardRestDayFindsNextTrainingAcrossWeekBoundary() throws {
  let calendar = try dashboardCalendar("UTC")
  let sunday = try dashboardDate(2026, 7, 26, calendar: calendar)
  let nextMonday = try dashboardDate(2026, 7, 27, calendar: calendar)
  let days = [
    dashboardPlanDay(on: sunday, hasTraining: false),
    dashboardPlanDay(on: nextMonday, hasTraining: true),
  ]

  #expect(
    DashboardTodayPresentation.nextTrainingDate(
      after: sunday,
      days: days,
      selectedCalendar: PlanCalendarDayIdentity.utcCalendar
    ) == nextMonday
  )
}

@Test func dashboardShowsPostponedStateAfterRealPlanProjectionShift() async throws {
  let shiftInstant = try dashboardDate(
    2026,
    7,
    24,
    hour: 12,
    calendar: StudentDemoSeed.utcCalendar
  )
  let plan = StudentDemoSeed.makePlanView(today: shiftInstant)
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan]),
    now: { shiftInstant }
  )

  _ = try await repository.shiftPlan(
    id: plan.cycleID,
    studentID: StudentDemoSeed.studentID
  )
  let shiftedPlan = try #require(
    try await repository.fetchCurrentPlan(studentID: StudentDemoSeed.studentID)
  )
  let shiftedToday = DashboardTodayPresentation.planDay(
    on: shiftInstant,
    in: shiftedPlan.days,
    selectedCalendar: StudentDemoSeed.utcCalendar
  )
  let canUndo = PlanDayShiftLogic.canUndo(
    latestShiftCreatedAt: shiftedPlan.latestShiftCreatedAt,
    now: shiftInstant
  )

  #expect(shiftedToday == nil)
  #expect(
    DashboardTodayPresentation.actionState(
      isSelectedToday: true,
      isRestDay: true,
      canUndoPlanShift: canUndo
    ) == .postponed
  )
}

@Test func shiftedInSessionBeatsPostponedCardPastDeviceMidnight() async throws {
  let shanghai = try dashboardCalendar("Asia/Shanghai")
  // Shift at Shanghai noon July 24 — the UTC July 24 session moves to July 25.
  let shiftInstant = try dashboardDate(
    2026,
    7,
    24,
    hour: 12,
    calendar: StudentDemoSeed.utcCalendar
  )
  let plan = StudentDemoSeed.makePlanView(today: shiftInstant)
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan]),
    now: { shiftInstant }
  )
  _ = try await repository.shiftPlan(
    id: plan.cycleID,
    studentID: StudentDemoSeed.studentID
  )
  let shiftedPlan = try #require(
    try await repository.fetchCurrentPlan(studentID: StudentDemoSeed.studentID)
  )

  // Shanghai July 25, 00:30 — still UTC July 24, so the undo window is open…
  let pastDeviceMidnight = try dashboardDate(
    2026,
    7,
    25,
    hour: 0,
    minute: 30,
    calendar: shanghai
  )
  let canUndo = PlanDayShiftLogic.canUndo(
    latestShiftCreatedAt: shiftedPlan.latestShiftCreatedAt,
    now: pastDeviceMidnight
  )
  #expect(canUndo)

  // …but the device's "today" already holds the shifted-in session, so the
  // workout CTA must win over the postponed rest card.
  let deviceToday = DashboardTodayPresentation.planDay(
    on: pastDeviceMidnight,
    in: shiftedPlan.days,
    selectedCalendar: shanghai
  )
  let hasTraining = deviceToday.map { !$0.exercises.isEmpty } ?? false
  #expect(hasTraining)
  #expect(
    DashboardTodayPresentation.actionState(
      isSelectedToday: true,
      isRestDay: !hasTraining,
      canUndoPlanShift: canUndo
    ) == .primary
  )
}

@Test func demoCompetitionDateStaysThreeDaysAhead() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let calendar = Calendar.current

  #expect(
    CompetitionCountdownPresenter.daysUntil(
      competitionDate: profile.competitionDate ?? "",
      now: Date(),
      calendar: calendar
    ) == 3
  )
}

private func dashboardCalendar(_ identifier: String) throws -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: identifier))
  return calendar
}

private func dashboardDate(
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

private func dashboardPlanDay(
  on date: Date,
  hasTraining: Bool,
  exerciseName: String = "深蹲"
) -> StudentPlanDay {
  StudentPlanDay(
    id: UUID(),
    date: date,
    exercises: hasTraining ? [dashboardExercise(named: exerciseName)] : []
  )
}

private func dashboardExercise(named name: String = "深蹲") -> StudentPlanExercise {
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

@Test func liftSubtitleUsesFullNamesForOneOrTwoLiftsOnly() {
  #expect(DashboardTodayPresentation.liftSubtitle([.deadlift]) == "硬拉日")
  #expect(
    DashboardTodayPresentation.liftSubtitle([.squat, .bench]) == "深蹲、卧推日"
  )
  #expect(
    DashboardTodayPresentation.liftSubtitle([.squat, .bench, .deadlift]) == "蹲·推·拉"
  )
  #expect(DashboardTodayPresentation.liftSubtitle([]).isEmpty)
}
