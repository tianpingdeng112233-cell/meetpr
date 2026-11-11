import CoreModels
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func allDayScreenStartsWithCollapsedExercisesAndNoRetiredEntries() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let presentation = TodayWorkoutPresentation(
    day: day, drafts: drafts, references: [:], started: false)
  let screen = TodayWorkoutScreen<EmptyView>(
    content: .workout(presentation), weekCode: "W1D3", dayState: .current,
    reviewCompleted: false, unreadCount: 0, showsNotifications: true, coachName: "Coach",
    showsAskCoach: false, isPreparingAskCoach: false,
    collapsedExercises: .constant([:]), sequenceContent: EmptyView(),
    showsBackToToday: false, onBackToToday: {}, onRefresh: {}, onHistory: {},
    onReadiness: {}, onNotifications: {}, onMessageCoach: {}, onAskCoach: {},
    onStart: {}, onQuickLog: {}, onEdit: { _ in }, onVideoAction: { _ in },
    onComplete: {}, onUndoCompletion: {}, onShowReview: {})
  let inspected = try screen.inspect()
  #expect(try inspected.find(text: "W1").string() == "W1")
  let rowIDs = inspected.findAll {
    (try? $0.accessibilityIdentifier().hasPrefix("allDay.row.")) == true
  }
  #expect(rowIDs.isEmpty)
  #expect(inspected.findAll { try $0.accessibilityIdentifier() == "todayWorkout.quickLog" }.isEmpty)
  #expect(inspected.findAll { try $0.accessibilityIdentifier() == "todayWorkout.history" }.isEmpty)
}

@MainActor
@Test func allDayScreenOnlyExpandsOneSlotAndKeepsRepeatedExerciseRowsIndependent() async throws {
  let original = StudentAddedTestPlan.unsettledDemo().days[0]
  let first = try #require(original.exercises.first)
  let second = StudentPlanExercise(
    id: UUID(), exercise: first.exercise, sequenceIndex: 1,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, weightKg: 120, reps: 3)])
  let day = StudentPlanDay(id: original.id, date: original.date, exercises: [first, second])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: day.date, days: [day])
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let drafts = try #require(model.currentDrafts)
  let presentation = TodayWorkoutPresentation(
    day: day, drafts: drafts, references: [:], started: false)
  var noted: UUID?
  let sheet = AllDaySheetView(
    presentation: presentation, viewModel: model, editable: true,
    today: day.date, onVideo: { _ in }, onNote: { noted = $0.planExerciseID })
  #expect(
    try sheet.inspect().findAll {
      (try? $0.accessibilityIdentifier().hasPrefix("allDay.row.")) == true
    }.isEmpty)
  try sheet.inspect().find(viewWithAccessibilityIdentifier: "allDay.expand.\(second.id)").button()
    .tap()
  #expect(model.expandedAllDayExerciseID == second.id)
  #expect(
    try sheet.inspect().findAll {
      (try? $0.accessibilityIdentifier().hasPrefix("allDay.row.")) == true
    }.count == 1)
  #expect(model.allDaySheet[1].hidesName)
  try sheet.inspect().find(viewWithAccessibilityIdentifier: "allDay.note.\(second.id)").button()
    .tap()
  #expect(noted == second.id)
  #expect(model.currentDrafts?.allSatisfy { !$0.hasSavedRecord } == true)
}
