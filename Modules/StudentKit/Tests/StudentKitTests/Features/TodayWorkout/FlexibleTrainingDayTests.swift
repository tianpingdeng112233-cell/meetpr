import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func flexibleUndoAllowsLatestCompletionThreeDaysAgo() throws {
  let now = Date(timeIntervalSince1970: 1_800_001_000)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let day = try #require(plan.days.first)
    .replacingCompletion(completedAt: now.addingTimeInterval(-3 * 24 * 3600), source: "manual")

  #expect(FlexibleTrainingDay.canUndo(day.id, days: [day], now: now))
}

@Test(arguments: [
  (elapsed: 0.0, allowed: true),
  (elapsed: 601_200.0, allowed: true),  // 6 days 23 hours
  (elapsed: 604_799.0, allowed: true),  // 7 days minus 1 second
  (elapsed: 604_800.0, allowed: false),  // Exactly 7 days
  (elapsed: 604_860.0, allowed: false),  // 7 days plus 1 minute
  (elapsed: 691_200.0, allowed: false),  // 8 days
])
func flexibleUndoUsesRollingSevenDayWindow(elapsed: TimeInterval, allowed: Bool) throws {
  let now = Date(timeIntervalSince1970: 1_800_001_000)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let day = try #require(plan.days.first)
    .replacingCompletion(completedAt: now.addingTimeInterval(-elapsed), source: "manual")

  #expect(FlexibleTrainingDay.canUndo(day.id, days: [day], now: now) == allowed)
}

@Test func flexibleUndoRejectsEarlierCompletionWithinSevenDays() throws {
  let now = Date(timeIntervalSince1970: 1_800_001_000)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let first = try #require(plan.days.first)
    .replacingCompletion(completedAt: now.addingTimeInterval(-24 * 3600), source: "manual")
  let later = try #require(plan.days.last)
    .replacingCompletion(completedAt: now.addingTimeInterval(-3 * 24 * 3600), source: "manual")
  let days = [first, later]

  #expect(!FlexibleTrainingDay.canUndo(later.id, days: days, now: now))
  #expect(FlexibleTrainingDay.canUndo(first.id, days: days, now: now))
}

@Test func flexibleUndoRequiresACompletedDayInThePlan() throws {
  let now = Date(timeIntervalSince1970: 1_800_001_000)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let day = try #require(plan.days.first)
    .replacingCompletion(completedAt: nil, source: nil)

  #expect(!FlexibleTrainingDay.canUndo(day.id, days: [], now: now))
  #expect(!FlexibleTrainingDay.canUndo(day.id, days: [day], now: now))
  let completed = day.replacingCompletion(completedAt: now, source: "manual")
  #expect(!FlexibleTrainingDay.canUndo(UUID(), days: [completed], now: now))
}

@Test func flexibleWeekAllowsUnsettledDaysOnly() throws {
  let plan = StudentDemoSeed.makePlanView(today: Date(), todayOffset: 0)
  let cursor = try #require(StudentPlanSequence(days: plan.days).cursorDay)
  for day in plan.days {
    #expect(
      FlexibleTrainingDay.canWrite(day, in: plan.days)
        == (day.weekNumber == cursor.weekNumber && day.completedAt == nil))
  }
}

@Test func flexibleDefaultResumesLatestRealGymDayAndUndoUsesTimestamp() throws {
  let now = Date(timeIntervalSince1970: 1_800_001_000)
  let plan = StudentDemoSeed.makePlanView(today: now, todayOffset: 0)
  let days = plan.days.filter { $0.weekNumber == plan.days.first?.weekNumber }
    .map { $0.replacingCompletion(completedAt: nil, source: nil) }
  let first = try #require(days.first)
  let later = try #require(days.last)
  let exercise = try #require(later.exercises.first)
  let log = StudentSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planExerciseID: exercise.id,
    setIndex: 0, loggedAt: now, weightKg: 100, reps: 3, completed: true)
  #expect(FlexibleTrainingDay.defaultDay(days: days, logs: [log], now: now)?.id == later.id)
  #expect(
    FlexibleTrainingDay.defaultDay(days: days, logs: [log], now: now.addingTimeInterval(86400))?.id
      == first.id)
  let settled = [
    first.replacingCompletion(completedAt: now, source: "manual"),
    later.replacingCompletion(completedAt: now.addingTimeInterval(-60), source: "manual"),
  ]
  #expect(FlexibleTrainingDay.canUndo(first.id, days: settled, now: now))
  #expect(!FlexibleTrainingDay.canUndo(later.id, days: settled, now: now))
}
