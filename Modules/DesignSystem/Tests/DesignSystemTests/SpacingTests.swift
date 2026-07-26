import Testing

@testable import DesignSystem

@Suite("MeetPR spacing tokens")
struct SpacingTests {
  @Test("spacing values match the 4pt black-gold grid")
  func spacingValuesMatchBlackGoldGrid() {
    #expect(MeetPRSpacing.space1 == 4)
    #expect(MeetPRSpacing.space2 == 8)
    #expect(MeetPRSpacing.space3 == 12)
    #expect(MeetPRSpacing.space4 == 16)
    #expect(MeetPRSpacing.space5 == 20)
    #expect(MeetPRSpacing.space6 == 24)
    #expect(MeetPRSpacing.pageHorizontal == 20)
    #expect(MeetPRSpacing.compactPageHorizontal == 16)
    #expect(MeetPRSpacing.minimumHitTarget == 44)
  }
}
