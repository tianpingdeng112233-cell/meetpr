import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
struct AccessoryRIRKeypadTests {
  @Test func incompleteNewRowCanAdvanceThenSaveWhenRequiredFieldsAreFilled() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    row.input.weight = ""
    row.input.reps = ""
    let cells = WorkoutKeypadCell.cells(row: row, name: "Row", number: 1, includesEffort: true)
    let session = WorkoutKeypadSession()
    session.edit(cells: cells, rows: [row], at: cells[0].id) { row = $0 }
    session.update("7.5")
    session.commit("7.5")
    #expect(session.current?.field == .reps)
    #expect(row.input.weight == "7.5")
    #expect(
      try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID
      ).isEmpty)
    session.update("8")
    session.dismiss()
    #expect(session.current == nil)
    #expect(
      try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID
      ).isEmpty)
    #expect(await fixture.model.saveAccessoryRow(row))
    let saved = try #require(
      try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID
      ).first)
    #expect(saved.weightKg == 7.5 && saved.reps == 8 && saved.completed)
  }
  @Test(arguments: [false, true])
  func onlyOpeningAndDismissingDoesNotCreateOrRewrite(saved: Bool) async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    if saved {
      var initial = AccessoryRow(
        draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
      initial.input.rpe = "8"
      #expect(await fixture.model.saveAccessoryRow(initial))
    }
    let row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    let cell = try #require(
      WorkoutKeypadCell.cells(
        row: row, name: "Row", number: 1, includesEffort: true, effortMode: .rir
      ).last)
    let before = try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID)
    let session = WorkoutKeypadSession()
    session.edit(cells: [cell], rows: [row], at: cell.id) { _ in }
    session.dismiss()
    let after = try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID)
    #expect(after == before)
  }

  @Test(arguments: [false, true])
  func confirmingOrDismissingRetainsLocallyUntilExplicitSubmission(confirm: Bool) async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    let session = WorkoutKeypadSession()
    for value in ["2", "3"] {
      let wasCompleted = row.draft.completed
      #expect(wasCompleted == (value == "3"))
      let cell = try #require(
        WorkoutKeypadCell.cells(
          row: row, name: "Row", number: 1, includesEffort: true, effortMode: .rir
        ).last)
      session.edit(cells: [cell], rows: [row], at: cell.id) { row = $0 }
      session.update(value)
      #expect(row.input.rpe == value)
      if confirm { session.commit(value) } else { session.dismiss() }
      // Confirming/dismissing edits values only: a new row stays incomplete; a completed row stays complete.
      #expect(row.rir == Int(value))
      #expect(row.draft.completed == wasCompleted)
      #expect(fixture.model.currentDrafts?.first?.completed == wasCompleted)
      let beforeSubmit = try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID)
      #expect(beforeSubmit.first?.actualRIR == (value == "2" ? nil : 2))
      #expect(beforeSubmit.first?.completed == (wasCompleted ? true : nil))
      #expect(await fixture.model.saveAccessoryRow(row))
      let records = try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID)
      #expect(records.count == 1)
      #expect(records.first?.actualRIR == Int(value))
      #expect(records.first?.rpe == nil)
      #expect(records.first?.completed == true)
      row = AccessoryRow(
        draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    }
  }

  @Test(arguments: ["", "12"])
  func invalidDismissRestoresTheAcceptedRowWithoutSaving(text: String) async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    row.input.rpe = "8"
    #expect(await fixture.model.saveAccessoryRow(row))
    row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    let accepted = row
    let cell = try #require(
      WorkoutKeypadCell.cells(
        row: row, name: "Row", number: 1, includesEffort: true, effortMode: .rir
      ).last)
    #expect(cell.value.isEmpty)
    let session = WorkoutKeypadSession()
    session.edit(cells: [cell], rows: [row], at: cell.id) { row = $0 }
    session.update(text)
    session.dismiss()
    #expect(row == accepted)
    let records = try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: row.draft.planExerciseID)
    #expect(records.first?.rpe == 8)
    #expect(records.first?.actualRIR == nil)
    #expect(records.first?.completed == true)
  }
  @Test func dismissRetainsInputAndOpenCloseDoesNotWrite() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    let cell = try #require(
      WorkoutKeypadCell.cells(
        row: row, name: "Row", number: 1, includesEffort: true, effortMode: .rir
      ).last)
    let session = WorkoutKeypadSession()
    var commits = 0
    session.open(cells: [cell], at: cell.id) { cell, value in
      row.setKeypadValue(value, field: cell.field)
      commits += 1
    }
    session.update("2")
    session.dismiss()
    #expect(row.rir == 2)
    #expect(commits == 1)
    session.open(cells: [cell], at: cell.id) { _, _ in
      commits += 1
    }
    session.dismiss()
    #expect(commits == 1)
  }
  @Test func typingImmediatelyUpdatesTheRow() async throws {
    let fixture = try await accessoryFixture(logs: InMemoryStudentTrainingLogRepository())
    var row = AccessoryRow(
      draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
    let cell = try #require(
      WorkoutKeypadCell.cells(
        row: row, name: "Row", number: 1, includesEffort: true, effortMode: .rir
      ).last)
    let session = WorkoutKeypadSession()
    var commits = 0
    session.open(
      cells: [cell], at: cell.id,
      onChange: { cell, text in
        if let text { row.setKeypadValue(text, field: cell.field) }
      },
      onCommit: { _, _ in
        commits += 1
      })
    session.update("2")
    #expect(row.input.rpe == "2")
    #expect(row.input.effortMode == .rir)
    #expect(commits == 0)
  }
  @Test func recordedRPERowUnderRIRHeaderAcceptsAndSavesTwo() async throws {
    let logs = InMemoryStudentTrainingLogRepository()
    let fixture = try await accessoryFixture(logs: logs)
    let model = fixture.model
    var original = AccessoryRow(
      draft: try #require(model.currentDrafts?.first), previous: nil, unit: .kg)
    original.input.rpe = "8"
    #expect(await model.saveAccessoryRow(original))
    await model.load(dayID: fixture.day.id, studentID: StudentDemoSeed.studentID)
    var edited = AccessoryRow(
      draft: try #require(model.currentDrafts?.first), previous: nil, unit: .kg)
    #expect(edited.draft.hasSavedRecord)
    #expect(edited.input.effortMode == .rpe)

    // AccessoryLogCard passes its header mode separately from the saved row.
    // Drive the real row button, cell presentation, pad validation and save VM;
    // never preselect .rir in the keypad or convert the historical record in the test.
    let session = WorkoutKeypadSession()
    var didCommit = false
    let row = AccessoryLogRow(
      row: .constant(edited), number: 1, columnEffortMode: .rir,
      isSaving: false, isDisabled: false, showsValidation: false,
      onEdit: {}, onSave: {},
      onInput: { field in
        let cells = (model.currentDrafts ?? []).enumerated().flatMap { index, draft in
          WorkoutKeypadCell.cells(
            row: draft.id == edited.id
              ? edited : AccessoryRow(draft: draft, previous: nil, unit: .kg),
            name: "Row", number: index + 1, includesEffort: true, effortMode: .rir)
        }
        session.open(cells: cells, at: .init(rowID: edited.id, field: field)) { cell, value in
          edited.setKeypadValue(value, field: cell.field)
          didCommit = true
        }
      })
    #expect(
      try row.inspect().find(
        text: StudentStrings.replacing(
          .accessoryRecordedEffort, values: ["1", "RPE"])
      ).string().contains("RPE"))
    try row.inspect().find(viewWithAccessibilityIdentifier: "accessory.set.1.rpe")
      .button().tap()
    let cell = try #require(session.current)
    #expect(session.next?.field == .weight)
    #expect(cell.field == .rir)
    #expect(cell.context.hasSuffix("RIR"))
    var input = NumberPadTextInput(value: cell.value, field: cell.field)
    input.append("2")
    #expect(input.text == "2")
    // MeetPRNumberPad disables its primary button exactly when this is false.
    #expect(input.isValid)
    session.commit(input.committedText)
    #expect(didCommit)
    guard didCommit else { return }
    try await expectSavedRIR(edited, model: model, logs: logs)
  }

}

extension AccessoryRIRKeypadTests {
  private func expectSavedRIR(
    _ edited: AccessoryRow, model: TodayWorkoutViewModel,
    logs: InMemoryStudentTrainingLogRepository
  ) async throws {
    let beforeExplicitSave = try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: edited.draft.planExerciseID)
    #expect(beforeExplicitSave.first?.rpe == 8)
    #expect(beforeExplicitSave.first?.actualRIR == nil)
    #expect(beforeExplicitSave.first?.completed == true)
    #expect(await model.saveAccessoryRow(edited))
    let stored = try #require(
      try await logs.fetchLogsForExercise(
        studentID: StudentDemoSeed.studentID, planExerciseID: edited.draft.planExerciseID
      ).first)
    #expect(stored.actualRIR == 2)
    #expect(stored.rpe == nil)
  }

  @Test(arguments: [true, false])
  func minimalRIRHeaderInput(hasSavedRecord: Bool) async throws {
    let set = PrescribedSet(
      id: UUID(), setIndex: 0, weightKg: nil, intensity: .rir(2), reps: nil)
    let draft = TodayWorkoutSetRowDraft(
      id: set.id, planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "",
      isAccessory: true, prescribed: set,
      loggedSetID: hasSavedRecord ? UUID() : nil)
    var edited = AccessoryRow(draft: draft, previous: nil, unit: .kg)
    let session = WorkoutKeypadSession()
    var didCommit = false
    let row = AccessoryLogRow(
      row: .constant(edited), number: 1, columnEffortMode: .rir,
      isSaving: false, isDisabled: false, showsValidation: false,
      onEdit: {}, onSave: {},
      onInput: { field in
        let cells = WorkoutKeypadCell.cells(
          row: edited, name: "", number: 1, includesEffort: true, effortMode: .rir
        )
        .filter { $0.field == .rpe || $0.field == .rir }
        session.open(cells: cells, at: .init(rowID: edited.id, field: field)) { cell, value in
          edited.setKeypadValue(value, field: cell.field)
          didCommit = true
        }
      })
    try row.inspect().find(viewWithAccessibilityIdentifier: "accessory.set.1.rpe")
      .button().tap()
    let cell = try #require(session.current)
    var input = NumberPadTextInput(value: cell.value, field: cell.field)
    input.append("2")
    #expect(input.isValid)
    session.commit(input.committedText)
    #expect(didCommit)
    #expect(edited.rir == 2)
  }
}
