import Testing

@testable import DesignSystem

@Suite("MeetPR motion tokens")
struct MotionTests {
  @Test("iOS easing values match CSS cubic bezier")
  func easingValuesMatchCSSCubicBezier() {
    #expect(MeetPRMotion.easeIOSX1 == 0.32)
    #expect(MeetPRMotion.easeIOSY1 == 0.72)
    #expect(MeetPRMotion.easeIOSX2 == 0.0)
    #expect(MeetPRMotion.easeIOSY2 == 1.0)
    #expect(MeetPRMotion.durationFast == 0.20)
    #expect(MeetPRMotion.durationBase == 0.24)
    #expect(MeetPRMotion.durationSlow == 0.28)
  }
}
