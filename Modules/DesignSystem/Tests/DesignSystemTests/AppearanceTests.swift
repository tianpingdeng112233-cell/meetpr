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

  @Test func labelsAreStable() throws {
    #expect(
      try LocalizationCatalogTestSupport.simplifiedChinese(
        MeetPRAppearance.system.label,
        key: "designSystem.appearance.system"
      ) == "跟随系统"
    )
    #expect(
      try LocalizationCatalogTestSupport.simplifiedChinese(
        MeetPRAppearance.light.label,
        key: "designSystem.appearance.light"
      ) == "浅色"
    )
    #expect(
      try LocalizationCatalogTestSupport.simplifiedChinese(
        MeetPRAppearance.dark.label,
        key: "designSystem.appearance.dark"
      ) == "深色"
    )
  }
}
