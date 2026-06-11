import CoreModels
import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5UpdateW1SetSpecWritesDraftData() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  try await viewModel.updateW1SetSpec(Spec007Fixtures.setSpec(), for: exercise.id)

  #expect(viewModel.w1SetSpecs[exercise.id]?.targetValue == 100)
  #expect(exercise.setsData != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5W1SetSpecRestoresFromDraftStore() async throws {
  let store = try PlanningFixtures.store()
  let first = PlanningViewModel(repository: PlanningFixtures.repository(), draftStore: store)
  await first.bootstrap()
  first.selectStudent(PlanningFixtures.students()[1])
  first.selectDuration(4)
  first.sbdFrequency = SBDFrequency(squat: 1, bench: 0, deadlift: 0)
  first.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  first.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] = PlanningFixtures.squatID
  first.path = [.selectDuration, .assignFrequency, .selectMainLifts]
  try await first.goNext()
  try await first.proceedToStep5()
  let exercise = try #require(first.sortedDraftExercises.first)
  try await first.updateW1SetSpec(Spec007Fixtures.setSpec(targetValue: 122.5), for: exercise.id)

  let restored = PlanningViewModel(repository: PlanningFixtures.repository(), draftStore: store)
  await restored.bootstrap()

  #expect(restored.currentStep == .selectAccessories)
  #expect(restored.w1SetSpecs[exercise.id]?.targetValue == 122.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ToggleIntensityModePreservesPreviousValues() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)
  try await viewModel.updateW1SetSpec(Spec007Fixtures.setSpec(targetValue: 100), for: exercise.id)

  await viewModel.toggleIntensityMode(to: .rpe, for: exercise.id)
  try await viewModel.updateW1SetSpec(
    Spec007Fixtures.setSpec(intensityMode: .rpe, targetValue: 8.5),
    for: exercise.id
  )
  await viewModel.toggleIntensityMode(to: .weight, for: exercise.id)

  #expect(viewModel.w1SetSpecs[exercise.id]?.targetValue == 100)
  #expect(viewModel.w1SetSpecs[exercise.id]?.intensityMode == .weight)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5OneRMOnlyAvailableForMainLiftFamily() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let mainLift = try #require(viewModel.sortedDraftExercises.first { $0.isMainLift })
  let accessory = try #require(viewModel.sortedDraftExercises.first { !$0.isMainLift })

  #expect(viewModel.oneRM(for: mainLift) == nil)
  #expect(viewModel.oneRM(for: accessory) == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ZeroOneRMIsTreatedAsUnavailable() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let mainLift = try #require(viewModel.sortedDraftExercises.first { $0.isMainLift })
  viewModel.selectStudent(PlanningFixtures.studentWithoutOneRM())

  #expect(viewModel.oneRM(for: mainLift) == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5RPEValueIsClampedIntoRange() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  try await viewModel.updateW1SetSpec(
    Spec007Fixtures.setSpec(intensityMode: .rpe, targetValue: 12),
    for: exercise.id
  )

  #expect(viewModel.w1SetSpecs[exercise.id]?.targetValue == 10)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5WeightValueRoundsToHalfKilogramIncrement() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  try await viewModel.updateW1SetSpec(
    Spec007Fixtures.setSpec(targetValue: Decimal(1227) / Decimal(10)),
    for: exercise.id
  )

  #expect(viewModel.w1SetSpecs[exercise.id]?.targetValue == Decimal(245) / Decimal(2))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5SetCountIsClampedToAtLeastOne() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  try await viewModel.updateW1SetSpec(
    Spec007Fixtures.setSpec(setCount: 0),
    for: exercise.id
  )

  #expect(viewModel.w1SetSpecs[exercise.id]?.setCount == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5TargetRepsIsClampedToAtLeastOne() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  let exercise = try #require(viewModel.sortedDraftExercises.first)

  try await viewModel.updateW1SetSpec(
    Spec007Fixtures.setSpec(targetReps: 0),
    for: exercise.id
  )

  #expect(viewModel.w1SetSpecs[exercise.id]?.targetReps == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ProceedAutoFillsMissingSetSpecsWithDefaults() async throws {
  // Step 5 was removed; intensity input is inlined into Step 4 editor cards
  // which auto-persist defaults on appear. To cover the case where a card
  // never mounted (e.g. coach added an accessory then switched day),
  // proceedToStep6 backfills defaults for any missing specs.
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  #expect(viewModel.w1SetSpecs.isEmpty)

  try await viewModel.proceedToStep6()

  #expect(
    viewModel.sortedDraftExercises.allSatisfy { exercise in
      viewModel.setSpec(for: exercise.id) != nil
    }
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ProceedRoutesFourWeekPlanToRules() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5()
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)

  try await viewModel.proceedToStep6()

  #expect(viewModel.currentStep == .configureRules)
  #expect(viewModel.draftPlan?.currentStepRawValue == PlanningStep.configureRules.rawValue)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step5ProceedRoutesOneWeekPlanDirectlyToPreview() async throws {
  let viewModel = try await Spec007Fixtures.configuredViewModelForStep5(weeks: 1)
  try await Spec007Fixtures.fillAllW1SetSpecs(viewModel)

  try await viewModel.proceedToStep6()

  #expect(viewModel.currentStep == .previewWeekCards)
  #expect(viewModel.draftPlan?.planWeeks == 1)
}
