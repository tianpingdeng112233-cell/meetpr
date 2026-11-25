import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct CycleOutlookIntegrationTests {
  @Test func capsuleRequiresPublishedCompetitionLift() {
    let seed = StudentDemoSeed.makePlanView()
    let published = StudentPlanView(
      cycleID: seed.cycleID, weekIndex: 1,
      startDate: seed.startDate, publishedAt: Date(), days: seed.days)
    #expect(CycleOutlook.isAvailable(plan: published, profile: nil))
    #expect(!CycleOutlook.isAvailable(plan: nil, profile: nil))
    let unpublished = StudentPlanView(
      cycleID: seed.cycleID, weekIndex: 1,
      startDate: seed.startDate, days: seed.days)
    #expect(!CycleOutlook.isAvailable(plan: unpublished, profile: nil))
    let empty = StudentPlanView(
      cycleID: seed.cycleID, weekIndex: 1,
      startDate: seed.startDate, publishedAt: Date(), days: [])
    #expect(!CycleOutlook.isAvailable(plan: empty, profile: nil))
  }

  @Test func previewOutlookUsesNextPlanWithoutChangingCurrentWorkout() async throws {
    let fixture = HandoffWorkoutFixture()
    let model = TodayWorkoutViewModel(
      plans: fixture.repository,
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
    let original = model.currentDay?.id
    await model.browseAdjacentPlan(forward: true)
    #expect(model.showsCycleOutlook)
    let outlook = try await model.makeCycleOutlook(locale: Locale(identifier: "en"))
    #expect(outlook.totalWeeks == 12)
    #expect(!outlook.rows.isEmpty)
    #expect(outlook.rows.flatMap(\.cells).allSatisfy { !$0.done && !$0.isCurrent })
    let cell = try #require(outlook.rows.first?.cells.first { $0.dayID != nil })
    #expect(fixture.upcoming.days.contains { $0.id == cell.dayID })
    var selected = original
    var preview: UUID?
    let target = try #require(cell.dayID)
    TodayWorkoutSelectionResolver.selectCycleDay(
      target, plan: model.displayedPlan,
      isPreview: model.isPreviewingPlan, selectedDayID: &selected, previewDayID: &preview)
    #expect(preview == target)
    #expect(selected == original)
    #expect(
      TrainingSequenceLayout.page(days: fixture.upcoming.days, selectedDayID: preview)
        .visibleWeek?.days.contains { $0.day.id == target && $0.isSelected } == true)
    #expect(model.currentDay?.id == original)
    #expect(model.isPreviewingPlan)
    #expect(!(await model.commitSet(rowIndex: 0)))
  }

  @Test func rpeTableUsesSharedExtendedTableAndUnitRounding() {
    let kilograms = RPETable.values(e1RM: 265, unit: .kg)
    #expect(kilograms.count == 12)
    #expect(kilograms.allSatisfy { $0.count == 9 })
    #expect(kilograms[0][4] == "242.5")
    #expect(RPETable.values(e1RM: nil, unit: .kg)[0][0] == "100%")
    #expect(RPETable.values(e1RM: 265, unit: .lb)[0][4] == "535")
    #expect(RPETable.values(e1RM: nil, unit: .lb)[11][8] == "57.2%")
  }
}

extension CycleOutlookIntegrationTests {
  @Test func normalOutlookSelectionLoadsCompletedCurrentAndFutureDays() async throws {
    let fixture = HandoffWorkoutFixture()
    let model = TodayWorkoutViewModel(
      plans: fixture.repository,
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
    #expect(model.showsCycleOutlook)
    let outlook = try await model.makeCycleOutlook()
    let targets = Set(outlook.rows.flatMap(\.cells).compactMap(\.dayID))
    #expect(!targets.isEmpty)
    var selected = model.currentDay?.id
    var preview: UUID?
    for target in targets {
      TodayWorkoutSelectionResolver.selectCycleDay(
        target, plan: model.displayedPlan,
        isPreview: false, selectedDayID: &selected, previewDayID: &preview)
      await model.load(dayID: selected, studentID: StudentDemoSeed.studentID)
      #expect(model.currentDay?.id == target)
      #expect(preview == nil)
      #expect(!model.isPreviewingPlan)
    }
    let last = selected
    TodayWorkoutSelectionResolver.selectCycleDay(
      UUID(), plan: model.displayedPlan,
      isPreview: false, selectedDayID: &selected, previewDayID: &preview)
    #expect(selected == last)
    await fixture.repository.removeCurrentPlan()
    await model.load(dayID: nil, studentID: StudentDemoSeed.studentID)
    #expect(!model.showsCycleOutlook)
  }
}
