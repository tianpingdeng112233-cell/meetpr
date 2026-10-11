import CoreModels
import Testing
import ViewInspector

@testable import StudentKit

@Test func e1rmSelectionStartsAtTotalAndPreservesRangeAcrossSegments() {
  var selection = ProgressE1RMSelection()
  #expect(selection.segment == .total)
  #expect(selection.showsComparison)
  #expect(!selection.allowsPointSelection)
  selection.cycleRange()
  #expect(selection.range == .ninetyDays)
  selection.segment = .squat
  #expect(selection.range == .ninetyDays)
  #expect(!selection.showsComparison)
  #expect(selection.allowsPointSelection)
  selection.cycleRange()
  #expect(selection.range == .all)
  selection.segment = .deadlift
  #expect(selection.range == .all)
  selection.cycleRange()
  #expect(selection.range == .thirtyDays)
  #expect(ProgressE1RMSelection().segment == .total)
}

@MainActor
@Test(arguments: [LiftFamily.squat, .bench, .deadlift])
func everyEmptyLiftOffersTodayOnlyWhenAllTrainingIsEmpty(family: LiftFamily) throws {
  for empty in [true, false] {
    let card = GrowthE1RMCard(
      snapshot: .empty(family: family), range: .thirtyDays, isGlobalTrainingEmpty: empty,
      onOpenToday: {}, onCycleRange: {}, onSelectPoint: { _ in })
    let state = try card.inspect().find(GrowthZeroTrainingState.self).actualView()
    #expect(state.showsAction == empty)
  }
}
