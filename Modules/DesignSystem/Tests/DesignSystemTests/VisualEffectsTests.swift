import SwiftUI
import Testing

@testable import DesignSystem

@Suite("MeetPR v3 visual-effect tokens")
struct VisualEffectsTests {
  @Test("CTA molds preserve every CSS shadow layer")
  func ctaMoldsPreserveCSSLayers() {
    let dark = MeetPRVisualEffects.ctaMold(for: .dark)
    #expect(dark.map(\.offsetY) == [1.5, -2, 8])
    #expect(dark.map(\.blur) == [0, 3, 26])
    #expect(dark.map(\.spread) == [0, 0, 0])
    #expect(dark.map(\.isInset) == [true, true, false])

    let darkHeld = MeetPRVisualEffects.ctaMoldHeld(for: .dark)
    #expect(darkHeld.map(\.offsetY) == [1.5, -2, 0, 0])
    #expect(darkHeld.map(\.blur) == [0, 3, 0, 30])
    #expect(darkHeld.map(\.spread) == [0, 0, 4, 0])
    #expect(darkHeld.map(\.isInset) == [true, true, false, false])

    let light = MeetPRVisualEffects.ctaMold(for: .light)
    #expect(light.map(\.offsetY) == [6])
    #expect(light.map(\.blur) == [20])

    let lightHeld = MeetPRVisualEffects.ctaMoldHeld(for: .light)
    #expect(lightHeld.map(\.spread) == [4])
  }

  @Test("headline emboss preserves both theme recipes")
  func headlineEmbossPreservesBothThemeRecipes() {
    let dark = MeetPRVisualEffects.headlineEmboss(for: .dark)
    #expect(dark.map(\.offsetY) == [2, 3, -1])
    #expect(dark.map(\.blur) == [0, 3, 0])

    let light = MeetPRVisualEffects.headlineEmboss(for: .light)
    #expect(light.map(\.offsetY) == [1, 2])
    #expect(light.map(\.blur) == [0, 4])
  }
}
