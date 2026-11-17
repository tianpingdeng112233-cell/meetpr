import Foundation
import Testing
import ViewInspector

@testable import DesignSystem

@MainActor
@Suite("Number pad shortcuts")
struct NumberPadShortcutTests {
  @Test func allDayRIRHasSixQuickPicksAndNoNextAction() throws {
    let pad = MeetPRNumberPad(
      field: .rir, text: "2", contextText: "Squat", unit: nil, commitTitle: "Next",
      onTextCommit: { _ in }, onCancel: {},
      allDayActions: .init(effortField: .rir, onAdd: {}, onFillUp: {}, onFillDown: {}, onEffort: {})
    )
    let picks = try pad.inspect().findAll(ViewType.Button.self) {
      (try? $0.accessibilityIdentifier().hasPrefix("numberPad.quick.")) == true
    }
    #expect(picks.count == 6)
    #expect(try pad.inspect().findAll(ViewType.Text.self) { try $0.string() == "Next" }.isEmpty)
    #expect(
      try pad.inspect().find(viewWithAccessibilityIdentifier: "numberPad.digit..").button()
        .isDisabled())
  }

  @Test func allDayFunctionKeysAndQuickPicksForwardActions() throws {
    var actions: [String] = []
    var selected: String?
    let pad = MeetPRNumberPad(
      field: .rpe, text: "8", contextText: "Squat", unit: nil,
      onTextCommit: { _ in }, onCancel: { actions.append("dismiss") },
      onTextChange: { selected = $0 },
      allDayActions: .init(
        effortField: .rpe, onAdd: { actions.append("add") },
        onFillUp: { actions.append("up") }, onFillDown: { actions.append("down") },
        onEffort: { actions.append("effort") }))
    for key in ["add", "fillUp", "fillDown", "effort", "dismiss"] {
      try pad.inspect().find(viewWithAccessibilityIdentifier: "numberPad.\(key)").button().tap()
    }
    #expect(actions == ["add", "up", "down", "effort", "dismiss"])
    let picks = try pad.inspect().findAll(ViewType.Button.self) {
      (try? $0.accessibilityIdentifier().hasPrefix("numberPad.quick.")) == true
    }
    #expect(picks.count == 9)
    try pad.inspect().find(viewWithAccessibilityIdentifier: "numberPad.quick.8.5").button().tap()
    #expect(selected == "8.5")
  }

  @Test("Untouched localized weight keeps its original value", arguments: ["de_DE", "fr_FR"])
  func untouchedLocalizedWeight(localeIdentifier: String) {
    let input = MeetPRNumberPadInputValue(
      value: 100.5, field: .weight, locale: Locale(identifier: localeIdentifier)
    )

    #expect(input.placeholder == "100,5")
    #expect(input.resolve("") == 100.5)
  }

  @Test("Untouched accessory weight and RPE keep their decimals", arguments: ["de_DE", "fr_FR"])
  func untouchedAccessoryAndRPE(localeIdentifier: String) {
    let locale = Locale(identifier: localeIdentifier)
    let accessory = MeetPRNumberPadInputValue(
      value: 5.5, field: .weight, minimumWeight: 0, locale: locale
    )
    let rpe = MeetPRNumberPadInputValue(value: 8.5, field: .rpe, locale: locale)

    #expect(accessory.placeholder == "5,5")
    #expect(accessory.resolve("") == 5.5)
    #expect(rpe.placeholder == "8,5")
    #expect(rpe.resolve("") == 8.5)
  }

  @Test("Typed keypad decimal replaces the localized placeholder", arguments: ["de_DE", "fr_FR"])
  func typedValueWins(localeIdentifier: String) {
    let input = MeetPRNumberPadInputValue(
      value: 100.5, field: .weight, locale: Locale(identifier: localeIdentifier)
    )

    #expect(input.resolve("102.5") == 102.5)
    #expect(input.resolve("10") == 20)
  }

  @Test("Next and sync forward the untouched value", arguments: ["Next", "Sync"])
  func shortcutsForwardUntouchedValue(title: String) throws {
    var nextValue: Double?
    var syncValue: Double?
    let pad = MeetPRNumberPad(
      value: 100.5,
      syncTitle: "Sync",
      nextTitle: "Next",
      onCommit: { _ in Issue.record("Shortcut must not submit the confirm action") },
      onSync: { syncValue = $0 },
      onNext: { nextValue = $0 },
      onCancel: { Issue.record("Shortcut must not cancel") }
    )

    try pad.inspect().find(button: title).tap()

    #expect(title == "Next" ? nextValue == 100.5 : syncValue == 100.5)
  }
}

@MainActor
@Test func rirKeypadKeepsZeroAndTwoInsteadOfApplyingRPEFloor() {
  #expect(MeetPRNumberPad.snapped(0, field: .rir) == 0)
  #expect(MeetPRNumberPad.snapped(2, field: .rir) == 2)
  #expect(MeetPRNumberPad.snapped(12, field: .rir) == 9)
}
