import Testing

@testable import DesignSystem

@Suite("MeetPR radius tokens")
struct RadiusTests {
  @Test("radius values match the four-step black-gold scale")
  func radiusValuesMatchBlackGoldScale() {
    #expect(MeetPRRadius.chip == 10)
    #expect(MeetPRRadius.control == 12)
    #expect(MeetPRRadius.card == 16)
    #expect(MeetPRRadius.modal == 20)
    #expect(MeetPRRadius.pill == 999)
  }
}
