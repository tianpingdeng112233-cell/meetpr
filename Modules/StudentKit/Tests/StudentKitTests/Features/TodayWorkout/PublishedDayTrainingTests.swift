import CoreModels
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Suite struct PublishedDayTrainingTests {
  @Test func reopeningAlwaysSelectsCursorDespiteRecentWorkInAnotherWeek() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let student = StudentDemoSeed.studentID
    let cursor = try #require(StudentPlanSequence(days: plan.days).cursorDay)
    let day = try #require(plan.days.first { $0.weekNumber == cursor.weekNumber + 1 })
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = InMemoryStudentTrainingLogRepository()
    let model = TodayWorkoutViewModel(plans: plans, logs: logs)
    await model.load(dayID: day.id, studentID: student)
    #expect(await model.commitSet(rowIndex: 0))

    let reopened = TodayWorkoutViewModel(plans: plans, logs: logs)
    await reopened.load(dayID: nil, studentID: student)
    #expect(reopened.currentDay?.id == cursor.id)
    await reopened.load(dayID: day.id, studentID: student)
    #expect(reopened.currentDrafts?.first?.completed == true)
  }

  @Test(arguments: [-14, 0, 14])
  func anyWeekCanRecordAndCompleteWithoutAdvancingPastUnsettledWeek(daysFromSelected: Int)
    async throws
  {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let student = StudentDemoSeed.studentID
    let cursor = try #require(StudentPlanSequence(days: plan.days).cursorDay)
    let day = try #require(plan.days.first { $0.weekNumber == cursor.weekNumber + 1 })
    let exercise = try #require(day.exercises.first)
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = InMemoryStudentTrainingLogRepository()
    let now = day.date.addingTimeInterval(Double(daysFromSelected) * 86400)
    let model = TodayWorkoutViewModel(plans: plans, logs: logs, now: { now })
    await model.load(dayID: day.id, studentID: student)

    // Camera attachment allocation, editing and the exercise check all use this selected day.
    #expect(await model.ensureLoggedSetID(rowIndex: 0) != nil)
    model.updateWeight(rowIndex: 0, weight: 102.5)
    #expect(await model.saveAllDayRow(rowIndex: 0))
    #expect(await model.toggleAllDayExercise(exercise.id))
    model.addExtraSet(exerciseID: exercise.id)
    #expect(model.currentDrafts?.contains(where: \.isExtra) == true)
    let added = Exercise(
      id: UUID(), name: "Added", exerciseType: .accessory, isCompetitionLift: false,
      muscleGroups: [], equipment: [], createdAt: now)
    model.addStudentExercise(added)
    #expect(
      model.currentDrafts?.contains { $0.isStudentAdded && $0.exerciseID == added.id } == true)
    #expect(await model.completeCurrentDay())

    let saved = try #require(try await plans.fetchCurrentPlan(studentID: student))
    #expect(saved.days.first { $0.id == day.id }?.completedAt != nil)
    #expect(saved.days.first { $0.id == cursor.id }?.completedAt == nil)
    #expect(StudentPlanSequence(days: saved.days).cursorDay?.id == cursor.id)
    #expect(model.completionPhase == .celebration)
    let recorded = try await logs.fetchLogsForExercise(
      studentID: student, planExerciseID: exercise.id)
    #expect(recorded.first { $0.setIndex == 0 }?.weightKg == 102.5)

    let reopened = TodayWorkoutViewModel(plans: plans, logs: logs)
    await reopened.load(dayID: nil, studentID: student)
    #expect(reopened.currentDay?.id == cursor.id)
  }

  @Test(arguments: [false, true])
  func selectedDayControlsFollowSettlementRatherThanWeek(completed: Bool) async throws {
    let base = StudentAddedTestPlan.unsettledDemo()
    let cursor = try #require(StudentPlanSequence(days: base.days).cursorDay)
    let selected = try #require(base.days.first { $0.weekNumber > cursor.weekNumber })
    let day = selected.replacingCompletion(completedAt: completed ? Date() : nil, source: "manual")
    let plan = StudentPlanView(
      cycleID: base.cycleID, weekIndex: base.weekIndex, startDate: base.startDate,
      days: base.days.map { $0.id == day.id ? day : $0 })
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
    let drafts = try #require(model.currentDrafts)
    let first = try #require(drafts.first)
    let presentation = TodayWorkoutPresentation(
      day: day, drafts: drafts, references: [:], started: false)
    let editable = FlexibleTrainingDay.canWrite(day, in: model.planDays)
    var captured: UUID?
    var noted: UUID?
    let sheet = AllDaySheetView(
      presentation: presentation, viewModel: model, editable: editable, today: Date(),
      onVideo: { captured = $0.draft.id }, onNote: { noted = $0.planExerciseID })
    model.toggleAllDayExpansion(first.planExerciseID)
    let view = try sheet.inspect()
    #expect(presentation.completionAvailability(isEditable: editable).sticky == !completed)
    #expect(
      try view.find(viewWithAccessibilityIdentifier: "allDay.row.\(first.id)").isDisabled()
        == completed)
    for identifier in [
      "allDay.camera.\(first.id)", "allDay.complete.\(first.planExerciseID)",
      "allDay.note.\(first.planExerciseID)", "studentAdded.addExercise",
    ] {
      #expect(view.findAll { try $0.accessibilityIdentifier() == identifier }.isEmpty == completed)
    }
    if !completed {
      try view.find(viewWithAccessibilityIdentifier: "allDay.camera.\(first.id)").button().tap()
      try view.find(viewWithAccessibilityIdentifier: "allDay.note.\(first.planExerciseID)").button()
        .tap()
      #expect(captured == first.id)
      #expect(noted == first.planExerciseID)
    } else {
      #expect(await model.ensureLoggedSetID(rowIndex: 0) == nil)
      #expect(await model.toggleAllDayExercise(first.planExerciseID) == false)
      #expect(await model.completeCurrentDay() == false)
      model.addExtraSet(exerciseID: first.planExerciseID)
      #expect(model.currentDrafts?.count == drafts.count)
    }
  }

}
