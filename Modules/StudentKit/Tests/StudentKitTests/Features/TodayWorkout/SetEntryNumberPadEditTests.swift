import DesignSystem
import Testing

@testable import StudentKit

@MainActor
struct SetEntryNumberPadEditTests {
  @Test func mainPadRetainsInputOnDismissWithoutChangingBarbellRules() {
    var edit = SetEntryNumberPadEdit(field: .weight, original: "60", minimumWeight: 20)
    #expect(edit.valueToSave == nil)
    edit.update("7.5")
    #expect(edit.displayText == "7.5")
    #expect(edit.valueToSave == 20)
    edit.update("22.3")
    #expect(edit.valueToSave == 22.25)
    edit.update("")
    #expect(edit.valueToSave == nil)
    #expect(edit.original == "60")
  }
}
