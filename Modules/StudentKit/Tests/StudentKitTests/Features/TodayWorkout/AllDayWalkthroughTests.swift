import CoreModels
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
@Test func allDayEffortColumnKeepsItsLabelForValuesAndEmptyCells() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let first = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
  let cases: [EffortCellCase] = [
    .init(intensity: .rpe(8), rpe: 8, rir: nil, expected: "RPE 8"),
    .init(intensity: .rpe(8), rpe: nil, rir: nil, expected: "RPE —"),
    .init(intensity: .rir(2), rpe: nil, rir: 2, expected: "RIR 2"),
    .init(intensity: .rir(2), rpe: nil, rir: nil, expected: "RIR —"),
  ]
  for item in cases {
    var draft = first
    draft.prescribed = PrescribedSet(
      id: first.prescribed.id, setIndex: 0, intensity: item.intensity)
    draft.actualRPE = item.rpe
    draft.actualRIR = item.rir
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    #expect(try row.inspect().find(text: item.expected).string() == item.expected)
  }
}

@MainActor
@Test func perSetCaptureUsesVideoCameraAndKeepsItsAction() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
  var captured = false
  let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: { captured = true })
  let button = try row.inspect().find(viewWithAccessibilityIdentifier: "allDay.camera.\(draft.id)")
    .button()
  #expect(try button.labelView().find(ViewType.Image.self).actualImage().name() == "video")
  try button.tap()
  #expect(captured)
  let readOnly = AllDaySetRow(draft: draft, viewModel: nil, editable: false, onVideo: {})
  #expect(try readOnly.inspect().findAll(ViewType.Button.self).count == 1)
}

@MainActor
@Test func collapsedCurrentExerciseHasGoldOutlineBeforeAnyTap() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let group = try #require(AllDayExercise.build(drafts: drafts, collapsed: []).first)
  let block = AllDayExerciseBlock(
    group: group, note: "", expanded: false, hidesName: false, viewModel: nil,
    editable: false, onExpand: {}, onVideo: { _ in }, onNote: { _ in }, onRemove: {})
  let header = try block.inspect().find(
    viewWithAccessibilityIdentifier: "allDay.expand.\(group.id)"
  ).parent().hStack()
  #expect(try header.overlay().findAll(ViewType.Shape.self).count == 1)
}

@MainActor
@Test func exerciseSummaryKeepsPercentageLoadTogetherAndOffersLeadingSecondLine() throws {
  let day = StudentAddedTestPlan.unsettledDemo().days[0]
  var draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
  draft.prescribed = PrescribedSet(
    id: draft.prescribed.id, setIndex: 0, intensity: .percentage(75), reps: 1)
  draft.actualWeight = 150
  let group = AllDayExercise(id: draft.planExerciseID, rows: [draft], node: .current)
  let block = AllDayExerciseBlock(
    group: group, note: "", expanded: false, hidesName: false, viewModel: nil,
    editable: true, onExpand: {}, onVideo: { _ in }, onNote: { _ in }, onRemove: {})
  let load = try block.inspect().find(text: "150\u{00a0}(75%)")
  #expect(try load.multilineTextAlignment() == .leading)
  #expect(try load.parent().parent().vStack().alignment() == .leading)
}

private struct EffortCellCase {
  let intensity: PrescribedIntensity
  let rpe: Decimal?
  let rir: Int?
  let expected: String
}
