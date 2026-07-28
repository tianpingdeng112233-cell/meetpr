import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func completedDayWithoutMatchingFeedbackShowsPendingCopyData() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, hour: 22, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let logs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: now)
  let day = try #require(
    DashboardTodayPresentation.planDay(
      on: now,
      in: plan.days,
      selectedCalendar: calendar
    )
  )

  let presentation = try #require(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: logs,
      feedbackItems: historicalResponseFeedback(),
      now: now,
      selectedCalendar: calendar
    )
  )

  #expect(presentation.completedSetCount == day.exercises.flatMap(\.prescribedSets).count)
  #expect(presentation.submittedAt == logs.map(\.loggedAt).max())
  #expect(presentation.expectedResponseHours == 24)
}

@Test func matchingDayFeedbackSuppressesPendingCard() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, hour: 22, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let logs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: now)
  let day = try #require(
    DashboardTodayPresentation.planDay(
      on: now,
      in: plan.days,
      selectedCalendar: calendar
    )
  )
  let feedback = CoachFeedback(
    id: UUID(),
    coachID: StudentDemoSeed.coachID,
    studentID: StudentDemoSeed.studentID,
    dayDate: day.date,
    text: "已点评",
    postedAt: now
  )

  #expect(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: logs,
      feedbackItems: [feedback],
      now: now,
      selectedCalendar: calendar
    ) == nil
  )
}

@Test func exerciseLevelFeedbackSuppressesPendingCardWithoutDayDate() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, hour: 22, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let logs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: now)
  let day = try #require(
    DashboardTodayPresentation.planDay(
      on: now,
      in: plan.days,
      selectedCalendar: calendar
    )
  )
  let feedback = CoachFeedback(
    id: UUID(),
    coachID: StudentDemoSeed.coachID,
    studentID: StudentDemoSeed.studentID,
    planExerciseID: try #require(day.exercises.first?.id),
    text: "动作级点评",
    postedAt: now
  )

  #expect(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: logs,
      feedbackItems: [feedback],
      now: now,
      selectedCalendar: calendar
    ) == nil
  )
}

@Test func sameUTCDayFeedbackSuppressesPendingCardInNegativeDeviceTimeZone() throws {
  let utcCalendar = StudentDemoSeed.utcCalendar
  let losAngelesCalendar = try emptyStateCalendar("America/Los_Angeles")
  let planDate = try emptyStateDate(2026, 7, 27, calendar: utcCalendar)
  let now = try emptyStateDate(
    2026,
    7,
    27,
    hour: 12,
    calendar: losAngelesCalendar
  )
  let plan = StudentDemoSeed.makePlanView(today: planDate, todayOffset: 0)
  let day = try #require(plan.days.first)
  let logs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: planDate)
  let feedback = CoachFeedback(
    id: UUID(),
    coachID: StudentDemoSeed.coachID,
    studentID: StudentDemoSeed.studentID,
    dayDate: planDate,
    text: "同一 UTC 计划日点评",
    postedAt: now
  )

  #expect(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: logs,
      feedbackItems: [feedback],
      now: now,
      selectedCalendar: losAngelesCalendar
    ) == nil
  )
}

@Test func duplicateSetLogsCannotForgeACompletedWorkout() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, hour: 22, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let completeLogs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: now)
  let day = try #require(
    DashboardTodayPresentation.planDay(
      on: now,
      in: plan.days,
      selectedCalendar: calendar
    )
  )
  let first = try #require(completeLogs.first)
  let duplicate = StudentSetLog(
    id: UUID(),
    studentID: first.studentID,
    planExerciseID: first.planExerciseID,
    exerciseID: first.exerciseID,
    setIndex: first.setIndex,
    loggedAt: first.loggedAt.addingTimeInterval(60),
    weightKg: first.weightKg,
    reps: first.reps,
    rpe: first.rpe,
    completed: true
  )
  let forgedLogs = Array(completeLogs.dropLast()) + [duplicate]

  #expect(forgedLogs.count == completeLogs.count)
  #expect(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: forgedLogs,
      feedbackItems: [],
      now: now,
      selectedCalendar: calendar
    ) == nil
  )
}

@Test func completedHistoricalDateNeverShowsPendingFeedback() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let selectedDate = try emptyStateDate(2026, 7, 27, hour: 22, calendar: calendar)
  let now = try emptyStateDate(2026, 7, 28, hour: 10, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: selectedDate)
  let logs = StudentDemoSeed.makeSubmittedTodayLogs(plan: plan, today: selectedDate)
  let day = try #require(
    DashboardTodayPresentation.planDay(
      on: selectedDate,
      in: plan.days,
      selectedCalendar: calendar
    )
  )

  #expect(
    DashboardTodayPresentation.pendingFeedback(
      for: day,
      logs: logs,
      feedbackItems: [],
      now: now,
      selectedCalendar: calendar
    ) == nil
  )
}

@Test func restDayPreviewCalculatesTomorrowFromPlan() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, calendar: calendar)
  let plan = StudentDemoSeed.makeRestDayPlan(today: now)
  let preview = try #require(
    DashboardTodayPresentation.restDayPreview(
      after: now,
      days: plan.days,
      planStartDate: plan.startDate,
      fallbackWeekIndex: plan.weekIndex,
      selectedCalendar: calendar
    )
  )

  #expect(preview.dateLabel == "明天")
  #expect(preview.farewellText == "明天见。")
  #expect(preview.title == "明天 · 硬拉日 W1-D")
  #expect(preview.exerciseCount == 1)
  #expect(preview.setCount == 3)
  #expect(preview.estimatedMinutes == 15)
}

@Test func restDayPreviewUsesMonthDayWhenNextTrainingIsNotTomorrow() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, calendar: calendar)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let selectedDate = try #require(
    calendar.date(byAdding: .day, value: 1, to: plan.startDate)
  )
  let preview = try #require(
    DashboardTodayPresentation.restDayPreview(
      after: selectedDate,
      days: plan.days,
      planStartDate: plan.startDate,
      fallbackWeekIndex: plan.weekIndex,
      selectedCalendar: calendar
    )
  )

  #expect(preview.dateLabel == "7月30日")
  #expect(preview.farewellText == "7月30日见。")
  #expect(preview.title.hasPrefix("7月30日 · "))
}

@Test func restDayPreviewKeepsUTCDateAndAdvancesWeekAcrossSevenDayBoundary() throws {
  let utcCalendar = StudentDemoSeed.utcCalendar
  let losAngelesCalendar = try emptyStateCalendar("America/Los_Angeles")
  let planStartDate = try emptyStateDate(2026, 7, 27, calendar: utcCalendar)
  let nextTrainingDate = try emptyStateDate(2026, 8, 3, calendar: utcCalendar)
  let selectedDate = try emptyStateDate(
    2026,
    8,
    1,
    calendar: losAngelesCalendar
  )
  let sourceDay = try #require(
    StudentDemoSeed.makePlanView(today: planStartDate, todayOffset: 0).days.first
  )
  let nextTraining = StudentPlanDay(
    id: UUID(),
    date: nextTrainingDate,
    exercises: sourceDay.exercises
  )

  let preview = try #require(
    DashboardTodayPresentation.restDayPreview(
      after: selectedDate,
      days: [nextTraining],
      planStartDate: planStartDate,
      fallbackWeekIndex: 1,
      selectedCalendar: losAngelesCalendar
    )
  )

  #expect(preview.dateLabel == "8月3日")
  #expect(preview.title == "8月3日 · 深蹲日 W2-S")
}

@Test func expiredProjectionTriggersNextPlanWaitingState() throws {
  let calendar = StudentDemoSeed.utcCalendar
  let now = try emptyStateDate(2026, 7, 27, hour: 12, calendar: calendar)
  let plan = StudentDemoSeed.makePlanEndingToday(today: now)

  #expect(
    DashboardTodayPresentation.isAwaitingNextPlan(
      planEndDate: plan.endDate,
      cycleDays: plan.days,
      now: now,
      selectedCalendar: calendar
    )
  )
}

@Test func utcPlanEndDoesNotExpireEarlyInNegativeDeviceTimeZone() throws {
  let utcCalendar = StudentDemoSeed.utcCalendar
  let losAngelesCalendar = try emptyStateCalendar("America/Los_Angeles")
  let planEndDate = try emptyStateDate(2026, 7, 27, calendar: utcCalendar)
  let beforePlanDayBoundary = try emptyStateDate(
    2026,
    7,
    26,
    hour: 18,
    calendar: losAngelesCalendar
  )
  let atPlanDayBoundary = try emptyStateDate(
    2026,
    7,
    27,
    calendar: losAngelesCalendar
  )

  #expect(
    !DashboardTodayPresentation.isAwaitingNextPlan(
      planEndDate: planEndDate,
      cycleDays: [],
      now: beforePlanDayBoundary,
      selectedCalendar: losAngelesCalendar
    )
  )
  #expect(
    DashboardTodayPresentation.isAwaitingNextPlan(
      planEndDate: planEndDate,
      cycleDays: [],
      now: atPlanDayBoundary,
      selectedCalendar: losAngelesCalendar
    )
  )
}

@Test func weekSummaryUsesCompletedDaysVolumeAndPRCount() {
  let plan = StudentDemoSeed.makePlanEndingToday()
  let logs = StudentDemoSeed.makeAllCompletedLogs(plan: plan)
  let summary = DashboardTodayPresentation.weekSummary(
    days: plan.days,
    logs: logs,
    newPRCount: 2
  )

  #expect(summary.completedTrainingDays == summary.totalTrainingDays)
  #expect(summary.totalTrainingDays == plan.days.filter { !$0.exercises.isEmpty }.count)
  #expect(summary.totalVolumeKg > 0)
  #expect(summary.newPRCount == 2)
}

private func emptyStateDate(
  _ year: Int,
  _ month: Int,
  _ day: Int,
  hour: Int = 0,
  calendar: Calendar
) throws -> Date {
  try #require(
    calendar.date(
      from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour
      )
    )
  )
}

private func emptyStateCalendar(_ timeZoneIdentifier: String) throws -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
  return calendar
}

private func historicalResponseFeedback() -> [CoachFeedback] {
  StudentDemoSeed.makeFeedback().map { feedback in
    CoachFeedback(
      id: feedback.id,
      coachID: feedback.coachID,
      studentID: feedback.studentID,
      dayDate: nil,
      planExerciseID: nil,
      videoID: feedback.videoID,
      video: feedback.video,
      text: feedback.text,
      postedAt: feedback.postedAt,
      readAt: feedback.readAt
    )
  }
}
