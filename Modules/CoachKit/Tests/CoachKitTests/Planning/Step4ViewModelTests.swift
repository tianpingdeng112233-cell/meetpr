import CoreModels
import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4SwitchToDayLoadsAccessoriesForSelectedDay() async throws {
  let viewModel = try await configuredViewModelForStep4()
  let firstDayID = try #require(viewModel.sortedDraftDays.first?.id)

  await viewModel.switchToDay(firstDayID)

  #expect(viewModel.currentDayID == firstDayID)
  #expect(viewModel.accessoryFilters(for: firstDayID).isEmpty)
  #expect(viewModel.availableAccessories(for: firstDayID).count == 5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4UpdateFiltersReloadsMatchesForDay() async throws {
  let viewModel = try await configuredViewModelForStep4()
  let firstDayID = try #require(viewModel.sortedDraftDays.first?.id)

  await viewModel.updateFilters(
    AccessoryFilters(muscleGroups: [.quad], equipment: [.barbell]),
    for: firstDayID
  )

  let exercises = viewModel.availableAccessories(for: firstDayID)
  #expect(viewModel.accessoryFilters(for: firstDayID).equipment == [.barbell])
  #expect(exercises.map(\.id) == [PlanningFixtures.barbellLungeID])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4AddAccessoryWritesDraftWithPerDaySortOrder() async throws {
  let viewModel = try await configuredViewModelForStep4()
  let firstDayID = try #require(viewModel.sortedDraftDays.first?.id)
  let firstExercise = try #require(viewModel.availableAccessories(for: firstDayID).first)
  let secondExercise = try #require(
    viewModel.availableAccessories(for: firstDayID).dropFirst().first)

  try await viewModel.addAccessory(firstExercise, to: firstDayID)
  try await viewModel.addAccessory(secondExercise, to: firstDayID)

  let selected = viewModel.selectedAccessories(for: firstDayID)
  #expect(selected.count == 2)
  #expect(selected.allSatisfy { !$0.isMainLift })
  #expect(selected.map(\.sortOrder) == [1, 2])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4DeleteAccessoryRemovesOnlySelectedAccessory() async throws {
  let viewModel = try await configuredViewModelForStep4()
  let firstDayID = try #require(viewModel.sortedDraftDays.first?.id)
  let exercise = try #require(viewModel.availableAccessories(for: firstDayID).first)
  try await viewModel.addAccessory(exercise, to: firstDayID)
  let draftExerciseID = try #require(viewModel.selectedAccessories(for: firstDayID).first?.id)

  try await viewModel.deleteAccessory(draftExerciseID, from: firstDayID)

  #expect(viewModel.selectedAccessories(for: firstDayID).isEmpty)
  #expect(viewModel.draftPlan?.draftDays.first?.draftExercises.contains { $0.isMainLift } == true)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4KeepsFiltersAndSelectionsIndependentPerDay() async throws {
  let viewModel = try await configuredViewModelForStep4()
  let days = viewModel.sortedDraftDays
  let mondayID = try #require(days.first?.id)
  let wednesdayID = try #require(days.dropFirst().first?.id)
  let mondayExercise = try #require(viewModel.availableAccessories(for: mondayID).first)

  await viewModel.updateFilters(AccessoryFilters(muscleGroups: [.quad]), for: mondayID)
  try await viewModel.addAccessory(mondayExercise, to: mondayID)
  await viewModel.switchToDay(wednesdayID)

  #expect(viewModel.accessoryFilters(for: mondayID).muscleGroups == [.quad])
  #expect(viewModel.accessoryFilters(for: wednesdayID).isEmpty)
  #expect(viewModel.selectedAccessories(for: mondayID).count == 1)
  #expect(viewModel.selectedAccessories(for: wednesdayID).isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4ProceedAllowsEmptyAccessoryDays() async throws {
  let viewModel = try await configuredViewModelForStep4()

  try await viewModel.proceedToStep5()

  #expect(viewModel.draftPlan?.currentStepRawValue == PlanningStep.selectAccessories.rawValue)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4BootstrapRestoresCurrentDayAndSelectedAccessories() async throws {
  let suiteName = "Step4BootstrapRestoresCurrentDayAndSelectedAccessories"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defaults.removePersistentDomain(forName: suiteName)
  let store = try PlanningFixtures.store(stateDefaults: defaults)
  let repository = PlanningFixtures.repository()
  let viewModel = try await configuredViewModelForStep4(repository: repository, store: store)
  let secondDayID = try #require(viewModel.sortedDraftDays.dropFirst().first?.id)
  await viewModel.switchToDay(secondDayID)
  let exercise = try #require(viewModel.availableAccessories(for: secondDayID).first)
  try await viewModel.addAccessory(exercise, to: secondDayID)

  let restoredStore = DraftStore(modelContainer: store.modelContainer, stateDefaults: defaults)
  let restored = PlanningViewModel(repository: repository, draftStore: restoredStore)
  await restored.bootstrap()

  #expect(restored.currentStep == .selectAccessories)
  #expect(restored.currentDayID == secondDayID)
  #expect(restored.selectedAccessories(for: secondDayID).count == 1)
  defaults.removePersistentDomain(forName: suiteName)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
func configuredViewModelForStep4(
  repository: InMemoryPlanRepository = PlanningFixtures.repository(),
  store: DraftStore? = nil
) async throws -> PlanningViewModel {
  let viewModel = PlanningViewModel(
    repository: repository,
    draftStore: try store ?? PlanningFixtures.store()
  )
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[1])
  viewModel.selectDuration(4)
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)
  viewModel.toggleAssignment(dayOfWeek: 5, liftFamily: .deadlift)
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] =
    PlanningFixtures.squatID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 3, liftFamily: .bench)] =
    PlanningFixtures.benchID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 5, liftFamily: .deadlift)] =
    PlanningFixtures.deadliftID
  viewModel.path = [.selectDuration, .assignFrequency, .selectMainLifts]
  try await viewModel.goNext()
  return viewModel
}
