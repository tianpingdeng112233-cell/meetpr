import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6AddRuleAppendsWithDisplayOrder() async throws {
  let viewModel = try await configuredStep6ViewModel()

  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())

  #expect(viewModel.progressionRules.map(\.displayOrder) == [0, 1])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6UpdateRuleMutatesByID() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  var rule = try #require(viewModel.progressionRules.first)

  rule.ruleType = .rpeInc
  rule.incrementValue = 0.5
  try await viewModel.updateRule(rule)

  #expect(viewModel.progressionRules.first?.ruleType == .rpeInc)
  #expect(viewModel.progressionRules.first?.incrementValue == 0.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6RuleIncrementRoundsToPlanningIncrement() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  var rule = try #require(viewModel.progressionRules.first)

  rule.incrementValue = Decimal(27) / Decimal(10)
  try await viewModel.updateRule(rule)

  #expect(viewModel.progressionRules.first?.incrementValue == Decimal(5) / Decimal(2))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6DeleteRuleRemovesAndReorders() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let firstID = try #require(viewModel.progressionRules.first?.id)

  try await viewModel.deleteRule(id: firstID)

  #expect(viewModel.progressionRules.count == 1)
  #expect(viewModel.progressionRules.first?.displayOrder == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ToggleAppliedWeekNeverAddsW1() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let ruleID = try #require(viewModel.progressionRules.first?.id)

  try await viewModel.toggleAppliedWeek(1, for: ruleID)

  #expect(viewModel.progressionRules.first?.appliedWeeks.contains(1) == false)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ToggleAppliedWeekAddsAndRemovesW2ToW4() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let ruleID = try #require(viewModel.progressionRules.first?.id)

  try await viewModel.toggleAppliedWeek(2, for: ruleID)
  #expect(viewModel.progressionRules.first?.appliedWeeks.contains(2) == false)
  try await viewModel.toggleAppliedWeek(2, for: ruleID)
  #expect(viewModel.progressionRules.first?.appliedWeeks.contains(2) == true)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ToggleRuleExerciseAddsAndRemovesDraftExerciseID() async throws {
  let viewModel = try await configuredStep6ViewModel()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let ruleID = try #require(viewModel.progressionRules.first?.id)
  let exerciseID = try #require(viewModel.sortedDraftExercises.first?.id)

  try await viewModel.toggleRuleExercise(exerciseID, for: ruleID)
  #expect(viewModel.progressionRules.first?.exerciseIDs.contains(exerciseID) == true)
  try await viewModel.toggleRuleExercise(exerciseID, for: ruleID)
  #expect(viewModel.progressionRules.first?.exerciseIDs.contains(exerciseID) == false)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6CustomSequenceLengthTracksAppliedWeeks() async throws {
  let viewModel = try await configuredStep6ViewModel()
  let customRule = DraftProgressionRule(
    ruleType: .custom,
    customSequence: [100],
    customDimension: .weight,
    appliedWeeks: [2],
    displayOrder: 0
  )
  try await viewModel.addRule(customRule)
  let ruleID = try #require(viewModel.progressionRules.first?.id)

  try await viewModel.toggleAppliedWeek(3, for: ruleID)
  #expect(viewModel.progressionRules.first?.customSequence?.count == 2)
  try await viewModel.toggleAppliedWeek(2, for: ruleID)
  #expect(viewModel.progressionRules.first?.customSequence?.count == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ProceedAllowsEmptyRules() async throws {
  let viewModel = try await configuredStep6ViewModel()

  try await viewModel.proceedToStep7()

  #expect(viewModel.currentStep == .previewWeekCards)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6UncoveredExercisesUpdatesAfterRuleAssignment() async throws {
  let viewModel = try await configuredStep6ViewModel()
  let exerciseID = try #require(viewModel.sortedDraftExercises.first?.id)
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let ruleID = try #require(viewModel.progressionRules.first?.id)

  let before = viewModel.uncoveredExercises(for: 2).count
  try await viewModel.toggleRuleExercise(exerciseID, for: ruleID)
  let after = viewModel.uncoveredExercises(for: 2).count

  #expect(after == before - 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func configuredStep6ViewModel() async throws -> PlanningViewModel {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  return viewModel
}
