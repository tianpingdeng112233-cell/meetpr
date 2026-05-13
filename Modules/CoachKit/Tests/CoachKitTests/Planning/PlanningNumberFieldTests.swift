import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldTextFieldUpdateRoundsToIncrement() throws {
  let value = PlanningNumberField.normalizedValue(
    from: "100.7",
    range: 0...200,
    decimalIncrement: PlanningDecimalStep.half
  )

  #expect(value == 100.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldTextFieldClampsBelowRange() throws {
  let value = PlanningNumberField.normalizedValue(
    from: "-5",
    range: 0...100,
    decimalIncrement: PlanningDecimalStep.half
  )

  #expect(value == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldTextFieldClampsAboveRange() throws {
  let value = PlanningNumberField.normalizedValue(
    from: "999",
    range: 0...100,
    decimalIncrement: PlanningDecimalStep.half
  )

  #expect(value == 100)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldEmptyInputResetsToZero() throws {
  let value = PlanningNumberField.normalizedValue(
    from: "",
    range: 0...100,
    decimalIncrement: PlanningDecimalStep.half
  )

  #expect(value == 0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldIncrementButtonAddsStep() throws {
  let probe = NumberProbe(100)
  let inspected = try planningNumberField(probe: probe, range: 0...200).inspect()
  let incrementButton = try #require(inspected.findAll(ViewType.Button.self).last)

  try incrementButton.tap()

  #expect(probe.value == 102.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldDecrementButtonSubtractsStep() throws {
  let probe = NumberProbe(100)
  let inspected = try planningNumberField(probe: probe, range: 0...200).inspect()
  let decrementButton = try #require(inspected.findAll(ViewType.Button.self).first)

  try decrementButton.tap()

  #expect(probe.value == 97.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldIncrementDisabledAtUpperBound() throws {
  let probe = NumberProbe(100)
  let inspected = try planningNumberField(probe: probe).inspect()
  let incrementButton = try #require(inspected.findAll(ViewType.Button.self).last)

  #expect(incrementButton.isDisabled())
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldDecrementDisabledAtLowerBound() throws {
  let probe = NumberProbe(0)
  let inspected = try planningNumberField(probe: probe).inspect()
  let decrementButton = try #require(inspected.findAll(ViewType.Button.self).first)

  #expect(decrementButton.isDisabled())
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldTextInputSyncsOnExternalBindingChange() throws {
  let synced = PlanningNumberField.syncedTextInput(
    currentTextInput: "100",
    newValue: 200,
    isFocused: false,
    formatStyle: .number.precision(.fractionLength(0...1))
  )

  #expect(synced == "200")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningNumberFieldIncrementButtonCommitsPendingTextFirst() throws {
  let value = PlanningNumberField.steppedValue(
    afterCommitting: "100",
    range: 0...300,
    step: 2.5,
    decimalIncrement: PlanningDecimalStep.half
  )

  #expect(value == 102.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private final class NumberProbe {
  var value: Double

  init(_ value: Double) {
    self.value = value
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func planningNumberField(
  probe: NumberProbe,
  range: ClosedRange<Double> = 0...100,
  step: Double = 2.5,
  decimalIncrement: Decimal = PlanningDecimalStep.half
) -> PlanningNumberField {
  PlanningNumberField(
    value: Binding(
      get: { probe.value },
      set: { probe.value = $0 }
    ),
    range: range,
    step: step,
    decimalIncrement: decimalIncrement,
    unitLabel: "kg"
  )
}
