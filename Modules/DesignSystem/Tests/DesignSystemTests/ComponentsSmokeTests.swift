import SwiftUI
import Testing

@testable import DesignSystem

@Suite("MeetPR component smoke tests")
@MainActor
struct ComponentsSmokeTests {
  @Test("PrimaryButton instantiates")
  func primaryButtonInstantiates() {
    _ = PrimaryButton("Save Mesocycle") {}
  }

  @Test("SecondaryButton instantiates")
  func secondaryButtonInstantiates() {
    _ = SecondaryButton("Discard") {}
  }

  @Test("DangerButton instantiates")
  func dangerButtonInstantiates() {
    _ = DangerButton("Revoke Access") {}
  }

  @Test("IconButton instantiates")
  func iconButtonInstantiates() {
    _ = IconButton {}
  }

  @Test("Card instantiates")
  func cardInstantiates() {
    _ = Card {
      Text("Card")
    }
  }

  @Test("ElevatedCard instantiates")
  func elevatedCardInstantiates() {
    _ = ElevatedCard {
      Text("Elevated")
    }
  }

  @Test("Eyebrow instantiates")
  func eyebrowInstantiates() {
    _ = Eyebrow("PROTOCOL 01")
  }

  @Test("StatBlock instantiates")
  func statBlockInstantiates() {
    _ = StatBlock(label: "Squat Standard", value: "320", unit: "KG")
  }

  @Test("StatusBadge instantiates")
  func statusBadgeInstantiates() {
    _ = StatusBadge(status: .ready)
    _ = StatusBadge(status: .pending)
    _ = StatusBadge(status: .overdue)
    _ = StatusBadge(status: .completed)
    _ = StatusBadge(status: .live)
  }

  @Test("PRBadge instantiates")
  func prBadgeInstantiates() {
    _ = PRBadge(.newPR)
    _ = PRBadge(.pr)
  }

  @Test("MeetPRTextField instantiates")
  func textFieldInstantiates() {
    _ = MeetPRTextField("Phone", text: .constant("+86 138 0000 0000"))
  }

  @Test("NumericInput instantiates")
  func numericInputInstantiates() {
    _ = NumericInput(value: .constant(142.5), unit: .constant(.kg))
  }

  @Test("weight unit exposes both supported cases")
  func weightUnitExposesBothSupportedCases() {
    #expect(MeetPRWeightUnit.allCases == [.kg, .lb])
  }

  @Test("RPESlider instantiates")
  func rpeSliderInstantiates() {
    _ = RPESlider(value: .constant(8.5))
  }

  @Test("MeetPRListRow instantiates")
  func listRowInstantiates() {
    _ = MeetPRListRow(
      title: "Chen Lei",
      subtitle: "W3D1 - last logged 2h ago",
      status: .ready,
      showsPRBadge: true
    ) {}
  }
}
