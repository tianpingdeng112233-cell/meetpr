import CoreModels
import DesignSystem
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func expandedExerciseOnlyUsesGoldFillWhenCurrent() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  for node: AllDayExercise.Node in [.current, .pending, .completed] {
    let group = AllDayExercise(id: day.exercises[0].id, rows: drafts, node: node)
    let block = AllDayExerciseBlock(
      group: group, note: "", expanded: true, hidesName: false, viewModel: nil,
      editable: false, onExpand: {}, onVideo: { _ in }, onNote: { _ in }, onRemove: {})
    let header = try block.inspect().find(
      viewWithAccessibilityIdentifier: "allDay.expand.\(group.id)"
    ).parent().zStack()
    let fill = try header.background().shape().fillShapeStyle(Color.self)
    #expect(fill == (node == .current ? Color.MeetPR.goldRGB.opacity(0.10) : .clear))
    #expect(try header.overlay().findAll(ViewType.Shape.self).count == 1)
  }
}

@MainActor
@Test func expandedCoachNoteShowsAllLines() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let group = try #require(AllDayExercise.build(drafts: drafts, collapsed: []).first)
  let note = "第一行提醒\n第二行保持节奏\n第三行完整说明"
  let block = AllDayExerciseBlock(
    group: group, note: note, expanded: true, hidesName: false, viewModel: nil,
    editable: false, onExpand: {}, onVideo: { _ in }, onNote: { _ in }, onRemove: {})
  let text = try block.inspect().find(
    text: StudentStrings.replacing(.allDayCoachNote, values: [note]))
  #expect(try text.lineLimit() == nil)
  #expect(try text.string().contains("第三行完整说明"))
}

@MainActor
@Test func exerciseMessageUsesAnIconAndCenteredDialogCopy() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let group = try #require(AllDayExercise.build(drafts: drafts, collapsed: []).first)
  var opened = false
  let block = AllDayExerciseBlock(
    group: group, note: "", expanded: true, hidesName: false, viewModel: nil,
    editable: true, onExpand: {}, onVideo: { _ in }, onNote: { _ in opened = true }, onRemove: {})
  let button = try block.inspect().find(viewWithAccessibilityIdentifier: "allDay.note.\(group.id)")
    .button()
  #expect(try button.labelView().findAll(ViewType.Text.self).isEmpty)
  try button.tap()
  #expect(opened)
  #expect(StudentStrings.localized(.allDayAskCoach) == "给教练留言")
  #expect(StudentStrings.localized(.allDayNotePlaceholder) == "这组感觉怎么样，或想问教练什么")
  let reference = ExerciseRefV1(
    exerciseName: "暂停卧推", dayDate: "2026-11-11", planDayID: day.id,
    planExerciseID: group.id, exerciseID: day.exercises[0].exercise.id)
  let dialog = ExerciseNoteSheet(reference: reference, send: { _ in true })
  #expect(try dialog.inspect().find(text: "给教练留言 · 暂停卧推").string() == "给教练留言 · 暂停卧推")
  #expect(try dialog.inspect().findAll(ViewType.NavigationStack.self).isEmpty)
  #expect(
    try dialog.inspect().find(button: StudentStrings.localized(.addedCancel)).labelView().text()
      .string() == "取消")
  #expect(try dialog.inspect().find(button: StudentStrings.localized(.allDaySend)).isDisabled())
}

@MainActor
@Test func percentagePrescriptionRemainsAtTheEndOfEachExpandedSet() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  var draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
  draft.prescribed = PrescribedSet(
    id: draft.prescribed.id, setIndex: 0, intensity: .percentage(60),
    percentageAnchor: .topSet, loadMode: .percentage, reps: 5)
  draft.actualWeight = nil
  #expect(AllDayExerciseSummary.build(rows: [draft]).segments.first?.load == "60% 顶组")
  for weight: Decimal? in [nil, 120] {
    draft.actualWeight = weight
    for editable in [true, false] {
      let row = AllDaySetRow(draft: draft, viewModel: nil, editable: editable, onVideo: {})
      let percentage = try row.inspect().find(text: "60%")
      #expect(try percentage.attributes().font() == .MeetPR.body(size: MeetPRFontMetrics.size11))
    }
  }
  #expect(AllDayExerciseSummary.build(rows: [draft]).segments.first?.load == "120")
}
