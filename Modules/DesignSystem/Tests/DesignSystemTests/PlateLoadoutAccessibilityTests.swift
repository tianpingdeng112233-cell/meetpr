import Testing

@testable import DesignSystem

/// VoiceOver must announce the collar the graphic draws (post-ship review
/// finding 2026-07-17: the label ignored `showCollar`, so a collar-only load
/// read out as an empty per-side breakdown).
@MainActor
@Suite struct PlateLoadoutAccessibilityTests {
  @Test func labelIncludesCollarOnlyWhenShown() {
    let plates: [Double] = [25, 5, 1.25]
    let bare = PlateLoadout.accessibilityText(plates, showCollar: false)
    let collared = PlateLoadout.accessibilityText(plates, showCollar: true)
    #expect(!bare.contains("collar"))
    #expect(collared.hasSuffix(" + 2.5kg collar"))
    #expect(collared.contains(PlateLoadout.breakdownText(plates)))
  }

  @Test func collarOnlyLoadStillAnnouncesCollar() {
    let text = PlateLoadout.accessibilityText([], showCollar: true)
    #expect(text.contains("2.5kg collar"))
  }
}
