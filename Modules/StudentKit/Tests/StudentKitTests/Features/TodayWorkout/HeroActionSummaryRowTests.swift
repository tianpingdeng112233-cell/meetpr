import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite struct HeroActionSummaryRowTests {
  @Test func summaryRowStartsCollapsedAndTogglesPrescriptions() throws {
    let exercise = makeExercise()
    let row = TodayWorkoutActionSummaryRow(exercise: exercise)
    #expect(
      try row.inspect().find(ViewType.Button.self).accessibilityValue().string()
        == DesignSystemStrings.collapsed)
    #expect((try? row.inspect().find(text: "125kg × 5")) == nil)

    var expanded = false
    let content = TodayWorkoutActionSummaryRowContent(
      exercise: exercise, expanded: Binding(get: { expanded }, set: { expanded = $0 }))
    #expect((try? content.inspect().find(text: "125kg × 5")) == nil)
    try content.inspect().find(ViewType.Button.self).tap()
    #expect(expanded)
    #expect(try content.inspect().find(text: "140kg × 3").string() == "140kg × 3")
    #expect(try content.inspect().find(text: "125kg × 5").string() == "125kg × 5")
    #expect(
      try content.inspect().find(ViewType.Button.self).accessibilityValue().string()
        == DesignSystemStrings.expanded)
    #expect(try content.inspect().findAll(ViewType.Button.self).count == 1)

    try content.inspect().find(ViewType.Button.self).tap()
    #expect(!expanded)
    #expect((try? content.inspect().find(text: "125kg × 5")) == nil)
    #expect(
      try content.inspect().find(ViewType.Button.self).accessibilityValue().string()
        == DesignSystemStrings.collapsed)
  }

  private func makeExercise() -> TodayWorkoutPresentation.Exercise {
    let rows = [Decimal(140), Decimal(125)].enumerated().map { index, weight in
      let set = PrescribedSet(
        id: UUID(), setIndex: index, weightKg: weight, loadMode: .fixedWeight,
        reps: index == 0 ? 3 : 5)
      let draft = TodayWorkoutSetRowDraft(
        id: set.id, planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "深蹲",
        isAccessory: false, prescribed: set)
      return TodayWorkoutPresentation.Row(
        id: set.id, stableIndex: index,
        record: TodayWorkoutPresentation.record(from: draft, index: index + 1, videoState: .none),
        draft: draft, suggestionOutcome: nil)
    }
    return .init(
      id: UUID(), stableIndex: 0, name: "深蹲", reference: "", cardSubtitle: "", note: "", rows: rows)
  }
}
