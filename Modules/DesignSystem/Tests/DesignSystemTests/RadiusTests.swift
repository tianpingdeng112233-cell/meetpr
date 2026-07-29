import Testing

@testable import DesignSystem

@Suite("MeetPR radius tokens")
struct RadiusTests {
  @Test("radius values match the six-step v3 scale")
  func radiusValuesMatchBlackGoldScale() {
    #expect(MeetPRRadius.micro == 4)
    #expect(MeetPRRadius.inset == 10)
    #expect(MeetPRRadius.chip == 12)
    #expect(MeetPRRadius.control == 12)
    #expect(MeetPRRadius.card == 16)
    #expect(MeetPRRadius.modal == 20)
    #expect(MeetPRRadius.pill == 999)
  }
}
