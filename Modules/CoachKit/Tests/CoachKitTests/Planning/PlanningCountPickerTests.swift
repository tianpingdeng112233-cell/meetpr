import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerEnumeratesTagsByStepWithinRange() throws {
  let tags = PlanningCountPicker.tags(for: 1...10, step: 0.5)
  #expect(tags.count == 19)
  #expect(tags.first == 0)
  #expect(tags.last == 18)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerTagValueRoundTrips() throws {
  let range: ClosedRange<Double> = 1...10
  let step = 0.5

  for tag in 0...18 {
    let produced = PlanningCountPicker.value(forTag: tag, range: range, step: step)
    let recovered = PlanningCountPicker.tag(for: produced, range: range, step: step)
    #expect(recovered == tag, "tag \(tag) → value \(produced) → tag \(recovered)")
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerSnapsValueOutsideGrid() throws {
  // Legacy draft with value 7.3 on a 0.5-step grid (range 1...10) → snap to nearest 7.5
  let tag = PlanningCountPicker.tag(for: 7.3, range: 1...10, step: 0.5)
  let snapped = PlanningCountPicker.value(forTag: tag, range: 1...10, step: 0.5)

  #expect(snapped == 7.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerClampsExternalValueAboveUpperBound() throws {
  // Value above range → snap to upperBound tag
  let tag = PlanningCountPicker.tag(for: 999, range: 1...20, step: 1)
  let snapped = PlanningCountPicker.value(forTag: tag, range: 1...20, step: 1)

  #expect(snapped == 20)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerIncrementButtonAddsStep() throws {
  let probe = CountProbe(5)
  let inspected = try planningCountPicker(
    probe: probe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  // Button order: minus (0), value-tap (1), plus (2). Value-tap opens
  // the wheel sheet; ± do the increment/decrement.
  try plusButton(in: inspected).tap()

  #expect(probe.value == 6)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerDecrementButtonSubtractsStep() throws {
  let probe = CountProbe(5)
  let inspected = try planningCountPicker(
    probe: probe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  try minusButton(in: inspected).tap()

  #expect(probe.value == 4)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerIncrementDisabledAtUpperBound() throws {
  let probe = CountProbe(20)
  let inspected = try planningCountPicker(
    probe: probe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  #expect(try plusButton(in: inspected).isDisabled())
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerDecrementDisabledAtLowerBound() throws {
  let probe = CountProbe(1)
  let inspected = try planningCountPicker(
    probe: probe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  #expect(try minusButton(in: inspected).isDisabled())
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerIncrementSnapsOffGridValueToNextTag() throws {
  // Legacy value 7.3 with step 0.5 → displayed as 7.5 (nearest tag) → + → 8.0
  let probe = CountProbe(7.3)
  let inspected = try planningCountPicker(
    probe: probe,
    label: "RPE",
    range: 1...10,
    step: 0.5
  ).inspect()

  try plusButton(in: inspected).tap()

  #expect(probe.value == 8.0)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private final class CountProbe {
  var value: Double

  init(_ value: Double) {
    self.value = value
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func planningCountPicker(
  probe: CountProbe,
  label: String,
  range: ClosedRange<Double>,
  step: Double
) -> PlanningCountPicker {
  PlanningCountPicker(
    label: label,
    value: Binding(
      get: { probe.value },
      set: { probe.value = $0 }
    ),
    range: range,
    step: step
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func plusButton(in inspected: InspectableView<ViewType.ClassifiedView>) throws
  -> InspectableView<ViewType.Button>
{
  try inspected.find(ViewType.Button.self) { button in
    (try? button.accessibilityLabel().string()) == "增加"
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func minusButton(in inspected: InspectableView<ViewType.ClassifiedView>) throws
  -> InspectableView<ViewType.Button>
{
  try inspected.find(ViewType.Button.self) { button in
    (try? button.accessibilityLabel().string()) == "减少"
  }
}
