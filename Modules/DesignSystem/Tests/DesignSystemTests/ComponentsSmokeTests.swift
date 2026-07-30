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

  @Test("BrandPrimaryButton instantiates")
  func brandPrimaryButtonInstantiates() {
    _ = BrandPrimaryButton("Start Training", isFullWidth: true) {}
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

  @Test("InitialAvatar instantiates")
  func initialAvatarInstantiates() {
    _ = InitialAvatar("Chen Lei")
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

  @Test("StatTile instantiates")
  func statTileInstantiates() {
    _ = StatTile(label: "Squat Standard", value: "320", unit: "KG")
  }

  @Test("StatusBadge instantiates")
  func statusBadgeInstantiates() {
    _ = StatusBadge(status: .ready)
    _ = StatusBadge(status: .pending)
    _ = StatusBadge(status: .overdue)
    _ = StatusBadge(status: .completed)
    _ = StatusBadge(status: .live)
  }

  @Test("SetRow instantiates")
  func setRowInstantiates() {
    _ = SetRow(
      index: 1,
      weight: 175,
      reps: 3,
      rpe: 8.5,
      status: .done,
      videoState: .uploaded
    )
  }

  @Test("GoldCTA instantiates all variants")
  func goldCTAInstantiates() {
    _ = GoldCTA("Start", variant: .primary) {}
    _ = GoldCTA("Cancel", variant: .secondary) {}
    _ = GoldCTA("Logout", variant: .danger) {}
    _ = GoldCTA("Postpone", variant: .link) {}
  }

  @Test("ExerciseCard instantiates")
  func exerciseCardInstantiates() {
    _ = ExerciseCard(
      exercise: "Deadlift",
      meta: "Last 170kg×3 @8",
      note: "Push the floor away",
      collapsed: false,
      sets: [
        ExerciseSetRecord(
          index: 1,
          weight: 175,
          reps: 3,
          rpe: 8.5,
          status: .done,
          videoState: .uploaded
        )
      ]
    )
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

  @Test("MeetPRTabBar preserves student defaults and supports a coach palette")
  func meetPRTabBarPalettes() {
    enum Tab: Hashable, Sendable {
      case today
      case messages
      case students
    }

    let items = [
      MeetPRTabBarItem(id: Tab.today, title: "今日", icon: .house),
      MeetPRTabBarItem(id: Tab.messages, title: "消息", icon: .message, badge: 3),
      MeetPRTabBarItem(id: Tab.students, title: "学员", icon: .students),
    ]
    let defaultBar = MeetPRTabBar(
      selection: .constant(Tab.messages),
      items: items
    )

    #expect(defaultBar.selectedColor == Color.MeetPR.goldCTA)
    #expect(defaultBar.unselectedColor == Color.MeetPR.textTertiary)
    #expect(defaultBar.badgeColor == Color.MeetPR.dangerFill)

    _ = MeetPRTabBar(
      selection: .constant(Tab.messages),
      items: items,
      selectedColor: Color.MeetPR.gold500,
      unselectedColor: Color.MeetPR.textDisabled,
      badgeColor: Color.MeetPR.danger
    )
  }
}
