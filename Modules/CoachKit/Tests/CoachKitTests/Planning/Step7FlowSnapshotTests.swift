import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step7ViewRendersFourWeekTabTitles() async throws {
  let viewModel = try await configuredPreviewViewModel()

  let inspected = try Step7WeekCardSwipeView(viewModel: viewModel).inspect()

  #expect(try inspected.find(text: "Week 1 / 4").string() == "Week 1 / 4")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weekCardRendersOneWeekTitle() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5(weeks: 1)
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()

  let inspected = try WeekCardView(viewModel: viewModel, weekNumber: 1).inspect()

  #expect(try inspected.find(text: "Week 1 / 1").string() == "Week 1 / 1")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weekCardRendersDaySectionsAndRows() async throws {
  let viewModel = try await configuredPreviewViewModel()

  let inspected = try WeekCardView(viewModel: viewModel, weekNumber: 1).inspect()

  #expect(try inspected.find(text: "周一").string() == "周一")
  #expect(try inspected.find(text: "竞技深蹲").string() == "竞技深蹲")
  #expect(try inspected.find(text: "4 组 × 5 次").string() == "4 组 × 5 次")
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
