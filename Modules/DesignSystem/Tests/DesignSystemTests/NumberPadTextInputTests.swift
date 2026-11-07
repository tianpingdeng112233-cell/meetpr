import Testing
import ViewInspector

@testable import DesignSystem

@MainActor
struct NumberPadTextInputTests {
  @Test func accessoryWeightDoesNotSnapToBarbell() {
    var input = NumberPadTextInput(value: "20", field: .weight)
    input.append("7")
    input.append(".")
    input.append("5")
    #expect(input.text == "7.5")
    #expect(input.isValid)
    input.append("5")
    #expect(input.text == "7.5")
  }
  @Test func rejectsInvalidEffortAndIntegerDecimals() {
    #expect(!NumberPadTextInput(value: "10.5", field: .rpe).isValid)
    #expect(!NumberPadTextInput(value: "9.2", field: .rpe).isValid)
    #expect(NumberPadTextInput(value: "9.5", field: .rpe).isValid)
    #expect(!NumberPadTextInput(value: "0", field: .reps).isValid)
    #expect(NumberPadTextInput(value: "99", field: .reps).isValid)
    #expect(!NumberPadTextInput(value: "100", field: .reps).isValid)
    var input = NumberPadTextInput(value: "2", field: .rir)
    input.append("0")
    input.append(".")
    #expect(input.text == "0")
    #expect(input.isValid)
  }
  @Test func deletingInitialValueProducesAnExplicitEmptyValue() {
    var input = NumberPadTextInput(value: "9.5", field: .rpe)
    input.deleteLast()
    input.deleteLast()
    input.deleteLast()
    #expect(input.text.isEmpty)
    #expect(input.isValid)
    input.append("8")
    #expect(input.text == "8")
  }
  @Test func textModeForwardsEmptyAndShowsContextUnitAndNextAction() throws {
    var received: String?
    let pad = MeetPRNumberPad(
      field: .rpe, text: "", contextText: "Row · Set 2 · RPE", unit: nil,
      commitTitle: "Next · Weight", onTextCommit: { received = $0 }, onCancel: {})
    #expect(try pad.inspect().find(text: "Row · Set 2 · RPE").string() == "Row · Set 2 · RPE")
    try pad.inspect().find(button: "Next · Weight").tap()
    #expect(received == "")
    let weight = MeetPRNumberPad(
      field: .weight, text: "7.5", contextText: "Row", unit: "LB",
      onTextCommit: { _ in }, onCancel: {})
    #expect(try weight.inspect().find(text: "LB").string() == "LB")
    #expect(try weight.inspect().find(text: "7.5").string() == "7.5")
  }
}
