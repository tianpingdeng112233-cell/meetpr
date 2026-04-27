import Testing

@testable import DesignSystem

@Suite("MeetPR spacing tokens")
struct SpacingTests {
  @Test("spacing values match CSS 8pt grid")
  func spacingValuesMatchCSSGrid() {
    #expect(MeetPRSpacing.xs == 4)
    #expect(MeetPRSpacing.sm == 8)
    #expect(MeetPRSpacing.md == 12)
    #expect(MeetPRSpacing.base == 16)
    #expect(MeetPRSpacing.lg == 24)
    #expect(MeetPRSpacing.xl == 32)
    #expect(MeetPRSpacing.xxl == 48)
    #expect(MeetPRSpacing.xxxl == 64)
  }
}
