import Testing

@testable import DesignSystem

@Suite("MeetPR typography tokens")
struct TypographyTests {
  @Test("font sizes match CSS type scale")
  func fontSizesMatchCSSTypeScale() {
    #expect(MeetPRFontMetrics.displayHeroSize == 44)
    #expect(MeetPRFontMetrics.title1Size == 34)
    #expect(MeetPRFontMetrics.title2Size == 28)
    #expect(MeetPRFontMetrics.headlineSize == 20)
    #expect(MeetPRFontMetrics.bodySize == 17)
    #expect(MeetPRFontMetrics.footnoteSize == 13)
    #expect(MeetPRFontMetrics.captionSize == 11)
    #expect(MeetPRFontMetrics.monoLabelSize == 12)
    #expect(MeetPRFontMetrics.displayNumeralSize == 60)
    #expect(MeetPRFontMetrics.displayUnitSize == 24)
  }

  @Test("tracking values match CSS em conversions")
  func trackingValuesMatchCSSEmConversions() {
    #expect(MeetPRFontMetrics.monoLabelTracking == 0.96)
    #expect(MeetPRFontMetrics.displayUnitTracking == 0.96)
  }
}
