import Foundation

struct TodayWorkoutSummaryExpansionState: Equatable, Sendable {
  private(set) var dayID: UUID?
  private(set) var isExpanded = true

  mutating func setExpanded(_ isExpanded: Bool, for dayID: UUID) {
    select(dayID: dayID)
    self.isExpanded = isExpanded
  }

  mutating func select(dayID: UUID) {
    guard self.dayID != dayID else { return }
    self.dayID = dayID
    isExpanded = true
  }
}
