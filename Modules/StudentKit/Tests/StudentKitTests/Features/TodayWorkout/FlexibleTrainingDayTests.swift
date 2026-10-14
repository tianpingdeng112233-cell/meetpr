import CoreModels
import Foundation
import Testing

@testable import StudentKit

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
