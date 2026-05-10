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

  #expect(try inspected.find(text: "递进 / 递减规则").string() == "递进 / 递减规则")
  #expect(try inspected.find(text: "+ 添加规则").string() == "+ 添加规则")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ViewRendersSingleRuleChips() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()
  try await viewModel.addRule(viewModel.makeDefaultProgressionRule())

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(try inspected.find(text: "规则 1").string() == "规则 1")
  #expect(try inspected.find(text: "W1").string() == "W1")
  #expect(try inspected.find(text: "W2").string() == "W2")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step6ViewRendersUncoveredSummary() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)
  try await viewModel.proceedToStep6()

  let inspected = try Step6ProgressionRulesView(viewModel: viewModel).inspect()

  #expect(try inspected.find(text: "未被任何规则覆盖").string() == "未被任何规则覆盖")
}
