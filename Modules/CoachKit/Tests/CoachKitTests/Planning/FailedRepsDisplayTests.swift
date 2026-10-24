import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func coachFailedRepsDisplayHidesPlaceholder() {
  let failed = DraftSetSpec(
    setCount: 3, targetReps: 1, intensityMode: .weight, targetValue: 80, setType: .failed)
  #expect(PlanningDisplay.repsText(failed, locale: Locale(identifier: "zh-Hans")) == "力竭")
  #expect(PlanningDisplay.repsText(failed, locale: Locale(identifier: "en")) == "to failure")
  let working = DraftSetSpec(
    setCount: 3, targetReps: 8, targetRepsMax: 12, intensityMode: .weight, targetValue: 80)
  #expect(PlanningDisplay.repsText(working) == "8-12")
}
