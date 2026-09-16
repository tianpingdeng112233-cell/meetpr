import CoreGraphics
import Testing

@testable import DesignSystem

@Suite("MeetPR motion tokens")
struct MotionTests {
  @Test("timing values match the interactive dark mockup")
  func timingValuesMatchInteractiveDarkMockup() {
    #expect(MeetPRMotion.durationRollUp == 0.62)
    #expect(MeetPRMotion.durationBloom == 0.75)
    #expect(MeetPRMotion.durationStamp == 0.52)
    #expect(MeetPRMotion.durationSpark == 0.80)
    #expect(MeetPRMotion.durationShimmer == 4.50)
    #expect(MeetPRMotion.durationHoldComplete == 1.10)
    #expect(MeetPRMotion.durationHoldCancel == 0.30)
    #expect(MeetPRMotion.sparkStagger == 0.018)
    #expect(MeetPRMotion.completionSlideInitialDelay == 0.34)
    #expect(MeetPRMotion.completionSlideStagger == 0.13)
    #expect(MeetPRMotion.completionSlideDuration == 0.46)
    #expect(MeetPRMotion.completionSlideOffset == 26)
    // motion/05 line 65: 340+i×130ms — the schedule call sites consume.
    #expect(MeetPRMotion.completionSlideDelay(0) == 0.34)
    #expect(abs(MeetPRMotion.completionSlideDelay(1) - 0.47) < 1e-9)
    #expect(abs(MeetPRMotion.completionSlideDelay(2) - 0.60) < 1e-9)
    #expect(abs(MeetPRMotion.completionSlideDelay(3) - 0.73) < 1e-9)
    #expect(MeetPRMotion.completionTickerDelay == 0.47)
    #expect(MeetPRMotion.completionTickerDuration == 0.90)
    #expect(MeetPRMotion.completionFadeDuration == 0.45)
  }

  @Test("surviving curves match feedback and reward transitions")
  func survivingCurvesMatchTransitions() {
    #expect(MeetPRMotion.easeOutX1 == 0.22)
    #expect(MeetPRMotion.easeOutY1 == 0.61)
    #expect(MeetPRMotion.easeOutX2 == 0.36)
    #expect(MeetPRMotion.easeOutY2 == 1.0)
    #expect(MeetPRMotion.rollX1 == 0.4)
    #expect(MeetPRMotion.rollY1 == 0)
    #expect(MeetPRMotion.rollX2 == 0.2)
    #expect(MeetPRMotion.rollY2 == 1.0)
    #expect(MeetPRMotion.easeOutCubic(0.5) == 0.875)
    #expect(MeetPRMotion.easeOutQuart(0.5) == 0.9375)
  }

  @Test("roll-up keyframes match the mockup's WAAPI segments")
  func rollUpStopsMatchMockupKeyframes() {
    #expect(MeetPRRollUpSpec.stops.map(\.progress) == [0, 0.3, 0.62, 1])
    #expect(MeetPRRollUpSpec.stops.map(\.rotation) == [0, -26, -52, -78])
    #expect(MeetPRRollUpSpec.stops.map(\.scaleY) == [1, 0.82, 0.48, 0.06])
    #expect(MeetPRRollUpSpec.stops.map(\.opacity) == [1, 0.92, 0.6, 0])
    #expect(MeetPRRollUpSpec.perspectiveDistance == 760)
    #expect(MeetPRRollUpSpec.containerHeight(at: 0, expandedHeight: 200) == 200)
    #expect(MeetPRRollUpSpec.containerHeight(at: 0.5, expandedHeight: 200) == 122)
    #expect(MeetPRRollUpSpec.containerHeight(at: 1, expandedHeight: 200) == 44)
    // The mockup interpolates to the *measured* header, floored at 44.
    #expect(
      MeetPRRollUpSpec.containerHeight(at: 1, expandedHeight: 200, collapsedHeight: 58) == 58
    )
    #expect(
      MeetPRRollUpSpec.containerHeight(at: 1, expandedHeight: 200, collapsedHeight: 30) == 44
    )
    #expect(MeetPRRollUpSpec.resolvedCollapsedHeight(nil) == 44)
  }

  @Test("roll-up haptics preserve the mockup's vibrate pattern")
  func rollUpHapticsPreserveCadenceAndChangingImpact() {
    let flattened = MeetPRRollUpSpec.hapticPulses.flatMap { pulse in
      pulse.pauseAfterMilliseconds > 0
        ? [pulse.durationMilliseconds, pulse.pauseAfterMilliseconds]
        : [pulse.durationMilliseconds]
    }
    #expect(flattened == [6, 50, 8, 60, 12])
    #expect(MeetPRRollUpSpec.hapticPulses.map(\.strength) == [.light, .medium, .heavy])
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
