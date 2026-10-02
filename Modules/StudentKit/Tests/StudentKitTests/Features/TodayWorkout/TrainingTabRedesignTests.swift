import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func futureDayUnlockCopyUsesPreviousTrainingDayName() throws {
  let previous = try #require(StudentDemoSeed.makePlanView().days.first { $0.dayOfWeek == 3 })

  #expect(TrainingSequenceText.unlockMessage(after: previous) == "练完 W1 · 硬拉日 后自动轮到这一节。")
}

@Suite struct TrainingTabRedesignTests {
  @Test func sequenceLayoutGroupsByWeekInCanonicalOrder() throws {
    let days = sequenceDays()
    let weeks = TrainingSequenceLayout.makeWeeks(days: days, selectedDayID: days[1].id)

    #expect(weeks.map(\.weekNumber) == [1, 2])
    #expect(weeks[0].days.map(\.day.id) == [days[0].id, days[1].id])
    #expect(weeks[0].days.map(\.state) == [.completed, .current])
    #expect(weeks[0].days[1].isSelected)
    #expect(try #require(weeks.last).days.map(\.state) == [.upcoming])
  }

  @Test func canonicalOrderUsesSortOrderThenIdentityAsFinalTieBreaker() {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    let higherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    let days = [
      StudentPlanDay(
        id: higherID, weekNumber: 1, dayOfWeek: 1, sortOrder: 2, date: date, exercises: []),
      StudentPlanDay(
        id: lowerID, weekNumber: 1, dayOfWeek: 1, sortOrder: 2, date: date, exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 1, sortOrder: 1, date: date, exercises: []),
    ]

    let ordered = StudentPlanSequence(days: days).orderedDays
    #expect(ordered[1].id == lowerID)
    #expect(ordered[2].id == higherID)
  }

  @Test func completedDaysAreReadOnlyAndOnlyCursorIsEditable() {
    let days = sequenceDays()
    let cursorID = StudentPlanSequence(days: days).cursorDay?.id
    #expect(days[0].completedAt != nil)
    #expect(cursorID == days[1].id)
    #expect(days[2].id != cursorID)
  }

  @Test func currentWeekFollowsCursorAndFallsBackToFinalCompletedWeek() {
    let days = sequenceDays()
    #expect(TrainingSequenceLayout.currentWeekNumber(days: days) == 1)

    let completed = days.map {
      $0.replacingCompletion(completedAt: Date(), source: "manual")
    }
    #expect(TrainingSequenceLayout.currentWeekNumber(days: completed) == 2)
  }

  private func sequenceDays() -> [StudentPlanDay] {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    return [
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 1, sortOrder: 0, date: date,
        completedAt: date, completionSource: "auto", exercises: []
      ),
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 2, sortOrder: 0, date: date, exercises: []),
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: 1, sortOrder: 0, date: date, exercises: []),
    ]
  }
}
