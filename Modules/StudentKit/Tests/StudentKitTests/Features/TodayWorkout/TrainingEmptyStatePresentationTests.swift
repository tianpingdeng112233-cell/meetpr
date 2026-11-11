import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func trainingEmptyStateDistinguishesFirstNextWeekAndCompletedPlan() throws {
  let now = try Date("2026-11-10T12:00:00Z", strategy: .iso8601)
  #expect(TrainingEmptyStatePresentation.resolve(plan: nil, now: now) == .firstPlan)
  let start = try Date("2026-10-19T00:00:00Z", strategy: .iso8601)
  let day = StudentPlanDay(
    id: UUID(), weekNumber: 3, date: start.addingTimeInterval(14 * 86400),
    completedAt: now.addingTimeInterval(-86400), exercises: [])
  let ongoing = StudentPlanView(
    cycleID: UUID(), weekIndex: 3, startDate: start,
    endDate: start.addingTimeInterval(55 * 86400), days: [day])
  #expect(
    TrainingEmptyStatePresentation.resolve(plan: ongoing, now: now)
      == .nextWeek(week: 4, completedSessions: 1))
  let finished = StudentPlanView(
    cycleID: UUID(), weekIndex: 3, startDate: start,
    endDate: start.addingTimeInterval(20 * 86400), days: [day])
  #expect(TrainingEmptyStatePresentation.resolve(plan: finished, now: now) == .completed(weeks: 3))
  let completedToday = StudentPlanView(
    cycleID: UUID(), weekIndex: 3, startDate: start,
    days: [day.replacingCompletion(completedAt: now, source: "manual")])
  #expect(TrainingEmptyStatePresentation.resolve(plan: completedToday, now: now) == nil)
  let uncompleted = StudentPlanView(
    cycleID: UUID(), weekIndex: 3, startDate: start,
    days: [day.replacingCompletion(completedAt: nil, source: nil)])
  #expect(TrainingEmptyStatePresentation.resolve(plan: uncompleted, now: now) == nil)
}
