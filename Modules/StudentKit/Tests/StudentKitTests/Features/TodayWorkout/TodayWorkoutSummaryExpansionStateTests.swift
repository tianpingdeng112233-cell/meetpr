import Foundation
import Testing

@testable import StudentKit

@Test func workoutSummaryExpandsWhenSelectionChangesToAnotherDay() {
  let firstDayID = UUID()
  let secondDayID = UUID()
  var state = TodayWorkoutSummaryExpansionState()

  state.setExpanded(false, for: firstDayID)
  #expect(!state.isExpanded)

  state.select(dayID: secondDayID)
  #expect(state.dayID == secondDayID)
  #expect(state.isExpanded)
}
