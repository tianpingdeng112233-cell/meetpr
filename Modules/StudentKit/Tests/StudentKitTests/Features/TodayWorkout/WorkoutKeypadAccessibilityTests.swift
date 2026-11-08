import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import DesignSystem
@testable import StudentKit

@MainActor
struct WorkoutKeypadAccessibilityTests {
  @Test func scrimIsHiddenFromAccessibilityButStillCancelsWithoutCommitting() async throws {
    let session = WorkoutKeypadSession()
    let cell = WorkoutKeypadCell(rowID: UUID(), field: .weight, value: "7.5")
    var values: [String] = []
    session.open(cells: [cell], at: cell.id) { _, value in
      values.append(value)
    }
    let scrim = try WorkoutKeypadOverlay(session: session).inspect()
      .find(viewWithAccessibilityIdentifier: "workout.keypad.dismiss").button()

    #expect(try scrim.accessibilityHidden())
    try scrim.tap()
    #expect(session.current == nil)
    #expect(values.isEmpty)
  }

  @Test func numberKeysRemainIndividuallyLabeledButtons() async throws {
    let session = WorkoutKeypadSession()
    let cell = WorkoutKeypadCell(rowID: UUID(), field: .weight, value: "7.5")
    session.open(cells: [cell], at: cell.id) { _, _ in }
    let panel = try WorkoutKeypadOverlay(session: session).inspect().find(MeetPRNumberPad.self)

    for digit in 0...9 {
      let button = try panel.find(button: String(digit))
      #expect(try button.accessibilityLabel().string() == String(digit))
      #expect(!button.isDisabled())
    }
  }

  @Test func nextAndConfirmKeepTheirLabelsAndCommitInsteadOfCancelling() async throws {
    let session = WorkoutKeypadSession()
    let rowID = UUID()
    let cells = [
      WorkoutKeypadCell(rowID: rowID, field: .weight, value: "7.5"),
      WorkoutKeypadCell(rowID: rowID, field: .reps, value: "8"),
    ]
    var values: [String] = []
    session.open(cells: cells, at: cells[0].id) { _, value in
      values.append(value)
    }
    let nextTitle = StudentStrings.replacing(.keypadNext, values: [cells[1].fieldTitle])
    let next = try WorkoutKeypadOverlay(session: session).inspect().find(button: nextTitle)

    #expect(!next.isDisabled())
    try next.tap()
    #expect(session.current?.id == cells[1].id)
    #expect(values.isEmpty)

    let confirm = try WorkoutKeypadOverlay(session: session).inspect()
      .find(button: DesignSystemStrings.confirm)
    #expect(!confirm.isDisabled())
    try confirm.tap()
    #expect(session.current == nil)
    #expect(values.isEmpty)
  }

  @Test func panelCancelRemainsAvailableWithoutCommitting() async throws {
    let session = WorkoutKeypadSession()
    let cell = WorkoutKeypadCell(rowID: UUID(), field: .rpe, value: "9.5")
    var values: [String] = []
    session.open(cells: [cell], at: cell.id) { _, value in
      values.append(value)
    }
    let cancel = try WorkoutKeypadOverlay(session: session).inspect()
      .find(MeetPRNumberPad.self).find(button: DesignSystemStrings.done)

    try cancel.tap()
    #expect(session.current == nil)
    #expect(values.isEmpty)
  }
}
