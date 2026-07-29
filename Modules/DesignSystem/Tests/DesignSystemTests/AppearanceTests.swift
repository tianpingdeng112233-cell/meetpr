import SwiftUI
import Testing

@testable import DesignSystem

@Suite struct MeetPRAppearanceTests {
  @Test func systemFollowsDeviceAppearance() {
    #expect(MeetPRAppearance.system.colorScheme == nil)
  }

  @Test func explicitCasesPinTheirScheme() {
    #expect(MeetPRAppearance.light.colorScheme == .light)
    #expect(MeetPRAppearance.dark.colorScheme == .dark)
  }

  @Test func unknownStoredValueFallsBackToSystem() {
    let restored = MeetPRAppearance(rawValue: "sepia")
    #expect(restored == nil)
    #expect((restored ?? .system).colorScheme == nil)
  }

  @Test func defaultPreferenceIsLight() {
    // ⚖️ 2026-07-28: fresh installs open in light mode.
    #expect(MeetPRAppearance.defaultPreference == .light)
    #expect(MeetPRAppearance.defaultPreference.colorScheme == .light)
  }

  @Test func labelsAreStable() {
    #expect(MeetPRAppearance.system.label == "跟随系统")
    #expect(MeetPRAppearance.light.label == "浅色")
    #expect(MeetPRAppearance.dark.label == "深色")
  }
}
