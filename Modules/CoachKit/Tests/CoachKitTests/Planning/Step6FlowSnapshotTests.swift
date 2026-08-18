import Foundation
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ViewRendersEmptyRulesState() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.progressionRulesTitle).string()
      == CoachPlanningStrings.progressionRulesTitle)
  #expect(
    try inspected.find(text: CoachPlanningStrings.addRule).string() == CoachPlanningStrings.addRule)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6RuleRequiresExerciseBeforeShowingValues() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.selectExerciseBeforeRule).string()
      == CoachPlanningStrings.selectExerciseBeforeRule)
  #expect(throws: (any Error).self) {
    try inspected.find(text: CoachPlanningStrings.changeAmount)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ViewRendersSingleRuleChips() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.ruleNumber(1)).string()
      == CoachPlanningStrings.ruleNumber(1))
  #expect(try inspected.find(text: "W1").string() == "W1")
  #expect(try inspected.find(text: "W2").string() == "W2")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6CustomRuleRestoresExerciseValuesAfterSwitchingActions() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  let exercises = viewModel.sortedDraftExercises
  let firstExercise = try #require(exercises.first)
  let secondExercise = try #require(exercises.dropFirst().first)
  let firstSequence = [
    Decimal(101),
    Decimal(205) / Decimal(2),
    Decimal(105),
  ]
  try await viewModel.addRule(
    DraftProgressionRule(
      ruleType: .custom,
      customSequence: firstSequence,
      customDimension: .weight,
      exerciseIDs: [firstExercise.id],
      appliedWeeks: [2, 3, 4],
      displayOrder: 0
    ))

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()
  let firstExerciseName = viewModel.exerciseName(for: firstExercise)
  let secondExerciseName = viewModel.exerciseName(for: secondExercise)
  let firstButton = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: firstExerciseName)) != nil
  }
  let secondButton = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: secondExerciseName)) != nil
  }

  try secondButton.tap()
  await Task.yield()
  await Task.yield()
  try firstButton.tap()
  await Task.yield()
  await Task.yield()

  let restoredRule = try #require(viewModel.progressionRules.first)
  #expect(restoredRule.exerciseIDs == [firstExercise.id])
  #expect(restoredRule.customSequence == firstSequence)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ViewRendersUncoveredSummary() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.uncoveredByRules.uppercased()).string()
      == CoachPlanningStrings.uncoveredByRules.uppercased())
}
