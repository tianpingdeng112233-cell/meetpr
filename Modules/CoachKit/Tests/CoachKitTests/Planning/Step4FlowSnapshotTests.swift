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

// SelectedAccessoryListSection was deleted as part of the Step 5 removal —
// ExerciseSetEditorCard now hosts both the row content and the delete button
// via its optional onDelete affordance.

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step4ScreenRendersSelectedSectionAndLibraryButton() async throws {
  let viewModel = try await configuredViewModelForStep4()

  let sut = Step4SelectAccessoriesView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "添加辅助动作").string() == "添加辅助动作")
  #expect(try inspected.find(text: "DAY 1").string() == "DAY 1")
  #expect(try inspected.find(text: "本日主项").string() == "本日主项")
  #expect(try inspected.find(text: "比赛式深蹲").string() == "比赛式深蹲")
  #expect(try inspected.find(text: "4 组 x 5 次 · 0kg").string() == "4 组 x 5 次 · 0kg")
  #expect(try inspected.find(text: "已选 0 个").string() == "已选 0 个")
  #expect(try inspected.find(text: "+ 添加动作").string() == "+ 添加动作")
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

  #expect(try inspected.find(text: "筛选").string() == "筛选")
  #expect(try inspected.find(text: "匹配 5 个").string() == "匹配 5 个")
}
