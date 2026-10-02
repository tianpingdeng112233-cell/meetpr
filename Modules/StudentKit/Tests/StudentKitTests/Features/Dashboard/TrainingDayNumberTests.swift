import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TrainingDayNumberTests {
  @Test func sparseWeekUsesOrdinalsIncludingCompletedDays() {
    let days = makeDays(slots: [2, 4, 6, 7])
    let numbers = StudentPlanSequence.dayNumbers(inWeek: days.reversed())
    #expect(days.compactMap { numbers[$0.id] } == [1, 2, 3, 4])
    #expect(DashboardTodayPresentation.code(for: days[2], in: days) == "W2D3")
    #expect(TrainingSequenceText.code(for: days[3], in: days) == "W2D4")
    #expect(
      DashboardTodayPresentation.progressSegments(days: days).map(\.dayNumber) == [1, 2, 3, 4])
  }

  @Test func insertedEarlierDayRenumbersAndSortOrderBreaksTies() {
    let days = makeDays(slots: [2, 4, 6, 7])
    let earlier = makeDays(slots: [1])[0]
    let reordered = [earlier] + days
    let numbers = StudentPlanSequence.dayNumbers(inWeek: reordered)
    #expect(reordered.compactMap { numbers[$0.id] } == [1, 2, 3, 4, 5])
    let tied = StudentPlanDay(
      id: UUID(), weekNumber: 2, dayOfWeek: 4, sortOrder: 10, date: .distantPast,
      exercises: [])
    let tiedNumbers = StudentPlanSequence.dayNumbers(inWeek: [tied] + days)
    #expect(tiedNumbers[days[1].id] == 2)
    #expect(tiedNumbers[tied.id] == 3)
  }

  @Test func duplicateIDsKeepFirstOrdinalWithoutCrashing() {
    let days = makeDays(slots: [2, 4, 6])
    let duplicated = [days[2], days[1], days[0], days[1]]
    let expected = [days[0].id: 1, days[1].id: 2, days[2].id: 4]

    #expect(StudentPlanSequence.dayNumbers(inWeek: duplicated) == expected)
    #expect(StudentPlanSequence.dayNumbers(inWeek: duplicated.reversed()) == expected)
  }

  private func makeDays(slots: [Int]) -> [StudentPlanDay] {
    slots.enumerated().map { index, slot in
      StudentPlanDay(
        id: UUID(), weekNumber: 2, dayOfWeek: slot, sortOrder: index,
        date: .distantPast, completedAt: index == 0 ? .distantPast : nil,
        exercises: [])
    }
  }
}
