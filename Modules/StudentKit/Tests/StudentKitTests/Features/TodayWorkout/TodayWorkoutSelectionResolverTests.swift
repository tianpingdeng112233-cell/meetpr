import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite struct TodayWorkoutSelectionResolverTests {
  @Test func initialSelectionPrefersExplicitIdentityThenCursor() {
    let days = selectionDays()
    #expect(
      TodayWorkoutSelectionResolver.initialSelection(explicitDayID: days[2].id, days: days)
        == days[2].id
    )
    #expect(
      TodayWorkoutSelectionResolver.initialSelection(explicitDayID: UUID(), days: days)
        == days[1].id
    )
  }

  @Test func jumpReturnsCursorAndIsClockIndependent() {
    let days = selectionDays()
    #expect(
      TodayWorkoutSelectionResolver.jumpToCurrentSelection(
        from: days[2].id,
        days: days
      ) == days[1].id
    )
    #expect(
      TodayWorkoutSelectionResolver.jumpToCurrentSelection(
        from: days[1].id,
        days: days
      ) == nil
    )
  }

  private func selectionDays() -> [StudentPlanDay] {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    return [
      StudentPlanDay(
        id: UUID(), weekNumber: 1, dayOfWeek: 1, date: date,
        completedAt: date, completionSource: "auto", exercises: []
      ),
      StudentPlanDay(id: UUID(), weekNumber: 1, dayOfWeek: 2, date: date, exercises: []),
      StudentPlanDay(id: UUID(), weekNumber: 2, dayOfWeek: 1, date: date, exercises: []),
    ]
  }
}
