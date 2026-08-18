import Foundation
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func dayChipBarRendersAssignedDayChips() throws {
  let draft = PlanningFixtures.draft()
  let extraDay = DraftPlanDay(id: PlanningFixtures.uuid(44), dayOfWeek: 3, sortOrder: 1)
  draft.draftDays.append(extraDay)

  let sut = DayChipBar(
    days: draft.draftDays,
    currentDayID: draft.draftDays.first?.id,
    dayTitle: { "DAY \($0)" },
    onSelect: { _ in }
  )
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "DAY 1").string() == "DAY 1")
  #expect(try inspected.find(text: "DAY 3").string() == "DAY 3")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryFilterSectionRendersThreeFacetRowsAndAllChips() throws {
  let sut = AccessoryFilterSection(filters: .empty) { _ in }
  let inspected = try sut.inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.muscleGroup).string()
      == CoachPlanningStrings.muscleGroup)
  #expect(
    try inspected.find(text: CoachPlanningStrings.equipment).string()
      == CoachPlanningStrings.equipment)
  #expect(
    try inspected.find(text: CoachPlanningStrings.movementPattern).string()
      == CoachPlanningStrings.movementPattern)
  #expect(try inspected.find(text: CoachPlanningStrings.all).string() == CoachPlanningStrings.all)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryMatchListSectionAddButtonTriggersCallback() throws {
  let exercise = PlanningFixtures.accessoryCatalog()[0]
  var addedExerciseID: UUID?
  let sut = AccessoryMatchListSection(
    exercises: [exercise],
    selectedExerciseIDs: [],
    isLoading: false
  ) { exercise in
    addedExerciseID = exercise.id
  }
  let inspected = try sut.inspect()
  let button = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: CoachLocalization.exerciseName(exercise))) != nil
  }

  try button.tap()

  #expect(addedExerciseID == exercise.id)
}

// SelectedAccessoryListSection was deleted as part of the Step 5 removal —
// ExerciseSetEditorCard now hosts both the row content and the delete button
// via its optional onDelete affordance.

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4ScreenRendersSelectedSectionAndLibraryButton() async throws {
  let viewModel = try await configuredViewModelForStep4()

  let sut = Step4SelectAccessoriesView(viewModel: viewModel)
  let inspected = try sut.inspect()
  let firstExercise = try #require(viewModel.sortedDraftExercises.first)

  #expect(
    try inspected.find(text: CoachPlanningStrings.addAccessoriesTitle).string()
      == CoachPlanningStrings.addAccessoriesTitle)
  #expect(try inspected.find(text: "DAY 1").string() == "DAY 1")
  #expect(
    try inspected.find(text: CoachPlanningStrings.todayMainLifts).string()
      == CoachPlanningStrings.todayMainLifts)
  #expect(
    try inspected.find(text: viewModel.exerciseName(for: firstExercise)).string()
      == viewModel.exerciseName(for: firstExercise))
  #expect(
    try inspected.find(
      text: CoachPlanningStrings.setRepIntensity(
        sets: 4, reps: "5", singularReps: false, intensity: "0kg")
    ).string()
      == CoachPlanningStrings.setRepIntensity(
        sets: 4, reps: "5", singularReps: false, intensity: "0kg"))
  #expect(
    try inspected.find(text: CoachPlanningStrings.selectedExerciseCount(0)).string()
      == CoachPlanningStrings.selectedExerciseCount(0))
  #expect(
    try inspected.find(text: CoachPlanningStrings.addExercise).string()
      == CoachPlanningStrings.addExercise)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryLibrarySheetRendersFilterAndMatchSections() async throws {
  let viewModel = try await configuredViewModelForStep4()
  guard let dayID = viewModel.currentDayID else {
    Issue.record("expected currentDayID after step 4 setup")
    return
  }

  let sut = AccessoryLibrarySheet(viewModel: viewModel, dayID: dayID)
  let inspected = try sut.inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.filter).string() == CoachPlanningStrings.filter)
  #expect(
    try inspected.find(text: CoachPlanningStrings.matchingExerciseCount(5)).string()
      == CoachPlanningStrings.matchingExerciseCount(5))
}
