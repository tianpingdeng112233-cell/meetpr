import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingReminderDefaultTests {
  @Test func currentWeekUsesRecommendedDatesIncludingCompletedAndShiftedDays() throws {
    let monday = try Date("2026-10-05T00:00:00Z", strategy: .iso8601)
    let days = [
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 1, date: monday,
        completedAt: monday, exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 2, date: monday,
        shiftedToDate: monday.addingTimeInterval(2 * 86_400), completedAt: monday,
        exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 4, date: monday.addingTimeInterval(4 * 86_400),
        exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 3, dayOfWeek: 7, date: monday.addingTimeInterval(6 * 86_400),
        exercises: []),
    ]
    let plan = StudentPlanView(cycleID: UUID(), weekIndex: 2, startDate: monday, days: days)
    let settings = TrainingReminderSettings.initial(recommendedWeekdays: [.tuesday], plan: plan)
    #expect(settings.weekdays == [.wednesday, .friday])
    #expect(!settings.isEnabled)
    #expect(settings.hour == 20)
  }

  @Test func noPlanFallsBackToProfileThenMondayWednesdayFriday() {
    #expect(
      TrainingReminderSettings.initial(recommendedWeekdays: [.sunday], plan: nil).weekdays
        == [.sunday])
    #expect(
      TrainingReminderSettings.initial(recommendedWeekdays: [], plan: nil).weekdays
        == [.monday, .wednesday, .friday])
  }

  @Test func savedSettingsIncludingEmptyWeekdaysStayUnchanged() {
    let saved = TrainingReminderSettings(isEnabled: true, weekdays: [], hour: 8, minute: 15)
    let day = StudentPlanDay(id: UUID(), date: .distantPast, exercises: [])
    let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: .distantPast, days: [day])
    #expect(
      TrainingReminderSettings.initial(
        recommendedWeekdays: [.sunday], plan: plan, storedSettings: saved) == saved)
  }
}
