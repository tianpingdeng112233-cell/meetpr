import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func dashboardWeekCellsAreSequenceOrdinalsNotCalendarSlots() {
  let date = Date(timeIntervalSince1970: 1_800_000_000)
  let days = [
    StudentPlanDay(
      id: UUID(), weekNumber: 3, dayOfWeek: 1, sortOrder: 0, date: date,
      completedAt: date, completionSource: "auto", exercises: []
    ),
    StudentPlanDay(
      id: UUID(), weekNumber: 3, dayOfWeek: 4, sortOrder: 0,
      date: date.addingTimeInterval(12 * 86_400), exercises: []
    ),
  ]

  let cells = DashboardTodayPresentation.progressSegments(days: days)
  #expect(cells.map(\.dayNumber) == [1, 4])
  #expect(cells.map(\.state) == [.done, .current])
}
