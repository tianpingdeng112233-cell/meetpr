import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7CurrentPreviewWeekDefaultsToOne() async throws {
  let viewModel = try await configuredStep7ViewModel()

  #expect(viewModel.currentPreviewWeek == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7SetCurrentPreviewWeekClampsToPlanBounds() async throws {
  let viewModel = try await configuredStep7ViewModel()

  viewModel.setCurrentPreviewWeek(9)
  #expect(viewModel.currentPreviewWeek == 4)
  viewModel.setCurrentPreviewWeek(0)
  #expect(viewModel.currentPreviewWeek == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7SetCurrentPreviewWeekLeavesDraftLastSavedAtUnchanged() async throws {
  let viewModel = try await configuredStep7ViewModel()
  let oldDate = try #require(viewModel.draftPlan?.lastSavedAt)

  viewModel.setCurrentPreviewWeek(2)

  #expect(viewModel.draftPlan?.lastSavedAt == oldDate)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7DerivedPreviewReflectsWeightRule() async throws {
  let viewModel = try await configuredStep7ViewModel()
  let exercise = try #require(viewModel.sortedDraftExercises.first)
  let derived = try #require(viewModel.derivedSetSpec(forWeek: 2, draftExercise: exercise))

  #expect(derived.targetValue == 105)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7ProceedToStep8IsPlaceholderAndDoesNotFinish() async throws {
  let viewModel = try await configuredStep7ViewModel()

  try await viewModel.proceedToStep8()

  #expect(viewModel.didFinish == false)
  #expect(viewModel.currentStep == .previewWeekCards)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func configuredStep7ViewModel() async throws -> PlanningViewModel {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())
  let ruleID = try #require(viewModel.progressionRules.first?.id)
  let exerciseID = try #require(viewModel.sortedDraftExercises.first?.id)
  try await viewModel.toggleRuleExercise(exerciseID, for: ruleID)
  try await viewModel.proceedToStep7()
  return viewModel
}
