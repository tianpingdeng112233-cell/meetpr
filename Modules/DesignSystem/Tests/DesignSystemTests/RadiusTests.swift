import Testing

@testable import DesignSystem

@Suite("MeetPR radius tokens")
struct RadiusTests {
  @Test("radius values match CSS")
  func radiusValuesMatchCSS() {
    #expect(MeetPRRadius.sm == 4)
    #expect(MeetPRRadius.md == 8)
    #expect(MeetPRRadius.lg == 12)
    #expect(MeetPRRadius.xl == 16)
    #expect(MeetPRRadius.pill == 999)
  }
}
