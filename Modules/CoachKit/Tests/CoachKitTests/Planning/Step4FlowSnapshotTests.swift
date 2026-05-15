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

  let sut = DayChipBar(days: draft.draftDays, currentDayID: draft.draftDays.first?.id) { _ in }
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "周一").string() == "周一")
  #expect(try inspected.find(text: "周三").string() == "周三")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accessoryFilterSectionRendersThreeFacetRowsAndAllChips() throws {
  let sut = AccessoryFilterSection(filters: .empty) { _ in }
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "肌群").string() == "肌群")
  #expect(try inspected.find(text: "器械").string() == "器械")
  #expect(try inspected.find(text: "模式").string() == "模式")
  #expect(try inspected.find(text: "全部").string() == "全部")
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
    (try? button.labelView().find(text: "哈克深蹲")) != nil
  }

  try button.tap()

  #expect(addedExerciseID == exercise.id)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func selectedAccessoryListSectionDeleteButtonTriggersCallback() throws {
  let accessory = DraftPlanExercise(
    id: PlanningFixtures.uuid(55),
    exerciseID: PlanningFixtures.accessoryID,
    isMainLift: false,
    sortOrder: 1
  )
  var deletedExerciseID: UUID?
  let sut = SelectedAccessoryListSection(
    accessories: [accessory],
    exerciseProvider: { _ in PlanningFixtures.accessoryCatalog()[0] },
    onDelete: { draftExerciseID in
      deletedExerciseID = draftExerciseID
    }
  )
  let inspected = try sut.inspect()
  let button = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: "删除")) != nil
  }

  try button.tap()

  #expect(deletedExerciseID == accessory.id)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4ScreenRendersChipFilterMatchAndSelectedSections() async throws {
  let viewModel = try await configuredViewModelForStep4()

  let sut = Step4SelectAccessoriesView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "添加辅助动作").string() == "添加辅助动作")
  #expect(try inspected.find(text: "周一").string() == "周一")
  #expect(try inspected.find(text: "筛选").string() == "筛选")
  #expect(try inspected.find(text: "匹配 5 个").string() == "匹配 5 个")
  #expect(try inspected.find(text: "已选 0 个").string() == "已选 0 个")
}
