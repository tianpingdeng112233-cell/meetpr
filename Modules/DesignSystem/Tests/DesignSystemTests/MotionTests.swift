import Testing

@testable import DesignSystem

@Suite("MeetPR motion tokens")
struct MotionTests {
  @Test("timing values match the interactive dark mockup")
  func timingValuesMatchInteractiveDarkMockup() {
    #expect(MeetPRMotion.durationPress == 0.12)
    #expect(MeetPRMotion.durationFast == 0.20)
    #expect(MeetPRMotion.durationScreen == 0.28)
    #expect(MeetPRMotion.durationSheet == 0.34)
    #expect(MeetPRMotion.durationRise == 0.50)
    #expect(MeetPRMotion.durationRollUp == 0.98)
    #expect(MeetPRMotion.durationBloom == 0.75)
    #expect(MeetPRMotion.durationStamp == 0.52)
    #expect(MeetPRMotion.durationSpark == 0.80)
    #expect(MeetPRMotion.durationGlow == 4.20)
    #expect(MeetPRMotion.durationShimmer == 4.50)
    #expect(MeetPRMotion.durationHoldComplete == 1.10)
    #expect(MeetPRMotion.durationHoldCancel == 0.30)
    #expect(MeetPRMotion.sparkStagger == 0.018)
    #expect(MeetPRMotion.riseInitialDelay == 0.02)
    #expect(MeetPRMotion.riseStagger == 0.04)
  }

  @Test("cubic curves match screen, sheet, and rise transitions")
  func cubicCurvesMatchTransitions() {
    #expect(MeetPRMotion.easeOutX1 == 0.2)
    #expect(MeetPRMotion.easeOutY1 == 0.7)
    #expect(MeetPRMotion.easeOutX2 == 0.2)
    #expect(MeetPRMotion.easeOutY2 == 1.0)
    #expect(MeetPRMotion.sheetX1 == 0.2)
    #expect(MeetPRMotion.sheetY1 == 0.8)
    #expect(MeetPRMotion.sheetX2 == 0.2)
    #expect(MeetPRMotion.sheetY2 == 1.0)
    #expect(MeetPRMotion.riseX1 == 0.215)
    #expect(MeetPRMotion.riseY1 == 0.61)
    #expect(MeetPRMotion.riseX2 == 0.355)
    #expect(MeetPRMotion.riseY2 == 1.0)
  }

  @Test("roll-up stops preserve mockup percentages and animated height")
  func rollUpStopsPreservePercentagesAndAnimatedHeight() {
    #expect(MeetPRRollUpSpec.stops.map(\.progress) == [0, 0.15, 0.32, 0.5, 0.67, 0.84, 1])
    #expect(
      MeetPRRollUpSpec.stops.map(\.translationFraction)
        == [0, -0.03, -0.17, -0.31, -0.46, -0.60, -0.72]
    )
    #expect(MeetPRRollUpSpec.translation(at: 1, cardHeight: 200) == -144)
    #expect(MeetPRRollUpSpec.containerHeight(at: 0, expandedHeight: 200) == 200)
    #expect(MeetPRRollUpSpec.containerHeight(at: 0.5, expandedHeight: 200) == 124)
    #expect(MeetPRRollUpSpec.containerHeight(at: 1, expandedHeight: 200) == 48)
  }

  @Test("roll-up haptics preserve pulse-pause cadence and changing impact")
  func rollUpHapticsPreserveCadenceAndChangingImpact() {
    let flattened = MeetPRRollUpSpec.hapticPulses.flatMap { pulse in
      pulse.pauseAfterMilliseconds > 0
        ? [pulse.durationMilliseconds, pulse.pauseAfterMilliseconds]
        : [pulse.durationMilliseconds]
    }
    #expect(flattened == [8, 60, 8, 60, 10, 60, 14])
    #expect(MeetPRRollUpSpec.hapticPulses.map(\.strength) == [.light, .medium, .medium, .heavy])
  }

  @Test("celebration sparks are eighteen particles staggered in six lanes")
  func celebrationSparksUseMockupStagger() {
    #expect(MeetPRCelebrationSpec.sparkCount == 18)
    let actual =
      (0..<MeetPRCelebrationSpec.sparkCount).map(MeetPRCelebrationSpec.sparkDelay(for:))
    let expected = [
      0, 0.018, 0.036, 0.054, 0.072, 0.09,
      0, 0.018, 0.036, 0.054, 0.072, 0.09,
      0, 0.018, 0.036, 0.054, 0.072, 0.09,
    ]

    for (actualDelay, expectedDelay) in zip(actual, expected) {
      #expect(abs(actualDelay - expectedDelay) < 0.000_001)
    }
  }
}
