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

@Test func flexiblePlanAllowsUnsettledDaysAcrossEveryWeek() throws {
  let plan = StudentDemoSeed.makePlanView(today: Date(), todayOffset: 0)
  for day in plan.days {
    #expect(
      FlexibleTrainingDay.canWrite(day, in: plan.days)
        == (day.completedAt == nil))
  }
}
