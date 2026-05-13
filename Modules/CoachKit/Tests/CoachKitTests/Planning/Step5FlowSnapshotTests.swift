import CoreModels
import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ViewRendersMainLiftAndAccessoryCards() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()

  let inspected = try Step5SetIntensityView(viewModel: viewModel).inspect()

  _ = try inspected.find(ViewType.ScrollView.self)
  #expect(viewModel.sortedDraftExercises.contains { viewModel.exerciseName(for: $0) == "比赛式深蹲" })
  #expect(viewModel.sortedDraftExercises.contains { !$0.isMainLift })
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func intensityModeToggleRendersBothModes() throws {
  let inspected = try IntensityModeToggleHarness().inspect()

  #expect(try inspected.find(text: "重量").string() == "重量")
  #expect(try inspected.find(text: "RPE").string() == "RPE")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldShowsPercentConversionWhenOneRMExists() throws {
  let inspected = try WeightInputField(value: 90, oneRM: 180) { _ in }.inspect()

  #expect(try inspected.find(text: "kg").string() == "kg")
  #expect(try inspected.find(text: "%1RM").string() == "%1RM")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func weightInputFieldExplainsMissingOneRM() throws {
  let inspected = try WeightInputField(value: 40, oneRM: nil) { _ in }.inspect()

  #expect(try inspected.find(text: "未设 1RM，无法换算 %1RM").string() == "未设 1RM，无法换算 %1RM")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct IntensityModeToggleHarness: View {
  @State private var mode: IntensityMode = .weight

  var body: some View {
    IntensityModeToggle(mode: $mode)
  }
}
