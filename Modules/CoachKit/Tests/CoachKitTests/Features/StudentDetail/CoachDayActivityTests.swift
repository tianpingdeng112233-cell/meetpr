import CoreModels
import Foundation
import Networking
import Testing

@testable import CoachKit

@Suite("Coach day ownership")
struct CoachDayActivityTests {
  @Test func sameWeekJumpDoesNotCompleteEarlierDay() {
    let earlier = day(offset: 1)
    let later = day(offset: 3, completed: true)
    let log = log(owner: later, date: earlier.date)
    #expect(!CoachDayActivity.hasTrained(earlier, days: [earlier, later], logs: [log]))
    #expect(CoachDayActivity.hasTrained(later, days: [earlier, later], logs: [log]))
  }

  @MainActor @Test func detailOverviewRosterAndReminderShareCompletion() throws {
    let earlier = day(offset: 1)
    let later = day(offset: 3, completed: true)
    let plan = StudentPlanView(
      cycleID: UUID(), weekIndex: 1,
      startDate: CoachStudentFeatureFixtures.startDate, days: [earlier, later])
    let legacy = StudentSetLog(
      id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
      planExerciseID: try #require(later.exercises.first?.id), setIndex: 0,
      loggedAt: earlier.date, weightKg: 100, reps: 3, completed: true)
    let days = StudentDetailViewModel.makeExecutionDays(
      plan: plan, logs: [legacy], now: earlier.date)
    #expect(days.first { $0.planDay?.id == earlier.id }?.logs.isEmpty == true)
    #expect(days.first { $0.planDay?.id == later.id }?.logs.count == 1)
    let overview = StudentDetailViewModel.makeOverview(days: days, feedback: [])
    #expect(overview.completedTrainingDays == 1)
    let row = StudentRosterViewModel.makeRow(
      summary: CoachStudentFeatureFixtures.summary(),
      plan: plan, logs: [], feedback: [], now: later.date.addingTimeInterval(86_400))
    #expect(row.trainingDays.first { $0.date == later.date }?.isCompleted() == true)
    #expect(!row.triageSignals.contains(.notTrained(daysMissed: 2)))
  }

  @Test func unfinishedTrainingSettlementAndLegacyFallback() {
    let target = day(offset: 1)
    #expect(
      CoachDayActivity.hasTrained(
        target, days: [target], logs: [log(owner: target, date: target.date)]))
    #expect(
      CoachDayActivity.hasTrained(
        target.replacingCompletion(completedAt: target.date, source: nil),
        days: [target], logs: []))
    #expect(
      !CoachDayActivity.hasTrained(
        target, days: [target], logs: [log(owner: target, date: target.date, completed: false)]))
    #expect(
      CoachDayActivity.hasTrained(
        target, days: [target], logs: [log(owner: nil, date: target.date)]))
    let unknown = day(offset: 0)
    #expect(
      CoachDayActivity.hasTrained(
        target, days: [target], logs: [log(owner: unknown, date: target.date)]))
  }

  @Test func crossWeekOwnershipFallsBackToCalendarDate() {
    let old = day(offset: 1, week: 2)
    let current = day(offset: 15, week: 4)
    let entry = log(owner: old, date: current.date)
    #expect(CoachDayActivity.hasTrained(current, days: [old, current], logs: [entry]))
    #expect(
      !CoachDayActivity.hasTrained(
        current, days: [old, current], logs: [log(owner: old, date: old.date)]))
  }

  @MainActor @Test func laggingStudentTrainsAcrossWeeksWithoutMissedReminder() {
    let oldFirst = day(offset: 1, week: 2)
    let oldSecond = day(offset: 3, week: 2)
    let currentFirst = day(offset: 15, week: 4)
    let currentSecond = day(offset: 17, week: 4)
    let logs = [
      log(owner: oldFirst, date: currentFirst.date),
      log(owner: oldSecond, date: currentSecond.date),
    ]
    let plan = StudentPlanView(
      cycleID: UUID(), weekIndex: 4,
      startDate: CoachStudentFeatureFixtures.startDate,
      days: [oldFirst, oldSecond, currentFirst, currentSecond])
    let now = currentSecond.date.addingTimeInterval(86_400)
    let row = StudentRosterViewModel.makeRow(
      summary: CoachStudentFeatureFixtures.summary(),
      plan: plan, coachLogs: logs, feedback: [], now: now)
    #expect(
      !row.triageSignals.contains {
        if case .notTrained = $0 { return true }
        return false
      })
    #expect(
      row.trainingDays.filter { $0.date >= currentFirst.date }.allSatisfy { $0.isCompleted() })
    let days = StudentDetailViewModel.makeExecutionDays(plan: plan, coachLogs: logs, now: now)
    #expect(
      StudentDetailViewModel.makeOverview(days: days, feedback: [], allLogs: logs)
        .completedTrainingDays == 2)
  }

  @MainActor @Test func latestActivityIncludesLogsNotPlacedInDisplayedWeek() {
    let target = day(offset: 1)
    let plan = StudentPlanView(
      cycleID: UUID(), weekIndex: 1,
      startDate: CoachStudentFeatureFixtures.startDate, days: [target])
    let latest = log(
      owner: nil, date: target.date.addingTimeInterval(20 * 86_400), completed: false)
    let days = StudentDetailViewModel.makeExecutionDays(
      plan: plan, coachLogs: [latest], now: target.date)
    #expect(
      StudentDetailViewModel.makeOverview(days: days, feedback: [], allLogs: [latest])
        .latestActivityAt == latest.loggedAt)
  }

  @Test func adhocOwnershipUsesTheSameWeekRule() {
    let earlier = day(offset: 1)
    let later = day(offset: 3)
    let entry = CoachSetLogDTO(
      id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
      planExerciseID: nil, planDayID: later.id, adhoc: true, exerciseID: UUID(),
      setIndex: 0, weightKg: 12.5, reps: 12, completed: true, loggedAt: earlier.date)
    #expect(!CoachDayActivity.hasTrained(earlier, days: [earlier, later], logs: [entry]))
    #expect(CoachDayActivity.hasTrained(later, days: [earlier, later], logs: [entry]))
  }

  func day(offset: Int, week: Int = 1, completed: Bool = false) -> StudentPlanDay {
    let exercise = CoachStudentFeatureFixtures.exercise()
    return StudentPlanDay(
      id: UUID(), weekNumber: week, dayOfWeek: offset + 1,
      date: CoachStudentFeatureFixtures.startDate.addingTimeInterval(Double(offset) * 86_400),
      completedAt: completed ? CoachStudentFeatureFixtures.startDate : nil,
      exercises: [
        StudentPlanExercise(
          id: UUID(), exercise: exercise.exercise,
          sequenceIndex: 0, prescribedSets: exercise.prescribedSets)
      ]
    )
  }

  func log(owner: StudentPlanDay?, date: Date, completed: Bool = true) -> CoachSetLogDTO {
    CoachSetLogDTO(
      id: UUID(), studentID: CoachStudentFeatureFixtures.studentID,
      planExerciseID: owner?.exercises.first?.id, setIndex: 0, weightKg: 100, reps: 3,
      completed: completed, loggedAt: date)
  }
}
