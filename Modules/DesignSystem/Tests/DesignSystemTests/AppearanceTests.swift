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

  @Test func labelsAreStable() {
    #expect(MeetPRAppearance.system.label == "跟随系统")
    #expect(MeetPRAppearance.light.label == "浅色")
    #expect(MeetPRAppearance.dark.label == "深色")
  }
}
