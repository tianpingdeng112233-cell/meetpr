import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerInitialValueShowsInCollapsedLabel() throws {
  let probe = CountProbe(5)
  let expandProbe = ExpandProbe(false)
  let inspected = try planningCountPicker(
    probe: probe,
    expandProbe: expandProbe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  let texts = inspected.findAll(ViewType.Text.self).compactMap { try? $0.string() }
  #expect(texts.contains("组数"))
  #expect(texts.contains("5"))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func planningCountPickerLabelTapTogglesIsExpandedBinding() throws {
  let probe = CountProbe(3)
  let expandProbe = ExpandProbe(false)
  let inspected = try planningCountPicker(
    probe: probe,
    expandProbe: expandProbe,
    label: "组数",
    range: 1...20,
    step: 1
  ).inspect()

  let toggleButton = try #require(inspected.findAll(ViewType.Button.self).first)
  try toggleButton.tap()

  #expect(expandProbe.value == true)
}

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
private final class CountProbe {
  var value: Double

  init(_ value: Double) {
    self.value = value
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private final class ExpandProbe {
  var value: Bool

  init(_ value: Bool) {
    self.value = value
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func planningCountPicker(
  probe: CountProbe,
  expandProbe: ExpandProbe,
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
    step: step,
    isExpanded: Binding(
      get: { expandProbe.value },
      set: { expandProbe.value = $0 }
    )
  )
}
