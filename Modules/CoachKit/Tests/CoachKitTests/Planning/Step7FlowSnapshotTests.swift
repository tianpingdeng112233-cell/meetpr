import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7ViewRendersFourWeekTabTitles() async throws {
  let viewModel = try await configuredPreviewViewModel()

  let inspected = try Step7WeekCardSwipeView(viewModel: viewModel).inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.weekPosition(1, total: 4)).string()
      == CoachPlanningStrings.weekPosition(1, total: 4))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weekCardRendersOneWeekTitle() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5(weeks: 1)
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()

  let inspected = try WeekCardView(viewModel: viewModel, weekNumber: 1).inspect()
  #expect(
    try inspected.find(text: CoachPlanningStrings.weekPosition(1, total: 1)).string()
      == CoachPlanningStrings.weekPosition(1, total: 1))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weekCardRendersDaySectionsAndRows() async throws {
  let viewModel = try await configuredPreviewViewModel()

  let inspected = try WeekCardView(viewModel: viewModel, weekNumber: 1).inspect()
  let firstExercise = try #require(viewModel.sortedDraftExercises.first)

  #expect(try inspected.find(text: "DAY 1").string() == "DAY 1")
  #expect(
    try inspected.find(text: viewModel.exerciseName(for: firstExercise)).string()
      == viewModel.exerciseName(for: firstExercise))
  #expect(
    try inspected.find(text: CoachPlanningStrings.setAndRepCount(sets: 4, reps: 5)).string()
      == CoachPlanningStrings.setAndRepCount(sets: 4, reps: 5))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weekCardRendersDerivedWeekFooter() async throws {
  let viewModel = try await configuredPreviewViewModel()

  let inspected = try WeekCardView(viewModel: viewModel, weekNumber: 2).inspect()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  _ = try inspected.find(ViewType.ScrollView.self)
  #expect(viewModel.derivedSetSpec(forWeek: 2, draftExercise: exercise) != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func configuredPreviewViewModel() async throws -> PlanningViewModel {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  try await viewModel.proceedToStep7()
  return viewModel
}
