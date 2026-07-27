import CoreGraphics
import Testing

@testable import DesignSystem

@Suite("MeetPR motion tokens")
struct MotionTests {
  @Test("timing values match the interactive dark mockup")
  func timingValuesMatchInteractiveDarkMockup() {
    #expect(MeetPRMotion.durationPress == 0.13)
    #expect(MeetPRMotion.durationFast == 0.20)
    #expect(MeetPRMotion.durationScreen == 0.28)
    #expect(MeetPRMotion.durationSheet == 0.34)
    #expect(MeetPRMotion.durationRise == 0.50)
    #expect(MeetPRMotion.durationRollUp == 0.62)
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
    #expect(MeetPRMotion.recordingRevealDelay == 0.36)
    #expect(MeetPRMotion.recordingRevealStagger == 0.09)
    #expect(MeetPRMotion.launchExitDuration == 0.20)
    #expect(MeetPRMotion.launchSwitchDelay == 0.14)
    #expect(MeetPRMotion.launchMorphDuration == 0.42)
    #expect(MeetPRMotion.launchGhostFadeDuration == 0.20)
    #expect(MeetPRMotion.launchHeroChildDuration == 0.22)
    #expect(MeetPRMotion.launchHeroChildStagger == 0.055)
    #expect(MeetPRMotion.feedbackExpandDuration == 0.38)
    #expect(MeetPRMotion.feedbackCollapseDuration == 0.28)
    #expect(MeetPRMotion.feedbackItemDuration == 0.20)
    #expect(MeetPRMotion.feedbackItemInitialDelay == 0.02)
    #expect(MeetPRMotion.feedbackItemStagger == 0.03)
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
  }

  @Test("launch morph geometry follows exact easeOutCubic interpolation")
  func launchMorphGeometryUsesReferenceTween() {
    let source = CGRect(x: 20, y: 600, width: 350, height: 62)
    let destination = CGRect(x: 20, y: 120, width: 350, height: 360)
    let midpoint = MeetPRLaunchMorphSpec.state(
      from: source,
      to: destination,
      rawProgress: 0.5
    )

    #expect(midpoint.frame.minX == 20)
    #expect(midpoint.frame.minY == 180)
    #expect(midpoint.frame.width == 350)
    #expect(midpoint.frame.height == 322.75)
    #expect(midpoint.cornerRadius == 17.5)
  }

  @Test("launch and feedback detail parameters stay locked to the HTML")
  func detailedMotionParametersMatchReference() {
    #expect(MeetPRMotion.launchSourceCornerRadius == 28)
    #expect(MeetPRMotion.launchDestinationCornerRadius == 16)
    #expect(MeetPRMotion.launchExitOffset == 26)
    #expect(MeetPRMotion.launchHeroChildOffset == 9)
    #expect(MeetPRMotion.riseInitialOffset == 72)
    #expect(MeetPRMotion.riseInitialScaleY == 0.88)
    #expect(MeetPRMotion.pillInitialOffset == -9)
    #expect(MeetPRMotion.pillInitialScaleY == 0.62)
    #expect(MeetPRMotion.feedbackItemOffset == -8)
    #expect(MeetPRMotion.feedbackPreviewFadeDuration == 0.05)
    #expect(MeetPRMotion.feedbackPreviewReturnDelay == 0.09)
    #expect(MeetPRMotion.feedbackPreviewReturnDuration == 0.18)
    #expect(MeetPRMotion.feedbackArrowDuration == 0.26)
    #expect(MeetPRMotion.launchDestinationFadeDuration == 0.28)
    #expect(MeetPRMotion.launchGhostFadeDuration == 0.20)
    #expect(MeetPRMotion.completionFadeDuration == 0.45)
  }

  @Test("feedback height overshoot starts after sixty-two percent and returns to zero")
  func feedbackOvershootMatchesReferenceSine() {
    #expect(MeetPRMotion.feedbackOvershoot(at: 0.62) == 0)
    #expect(abs(MeetPRMotion.feedbackOvershoot(at: 0.81) - 3) < 0.000_001)
    #expect(abs(MeetPRMotion.feedbackOvershoot(at: 1)) < 0.000_001)
  }

  @Test("cubic curves match screen, sheet, and rise transitions")
  func cubicCurvesMatchTransitions() {
    #expect(MeetPRMotion.easeOutX1 == 0.22)
    #expect(MeetPRMotion.easeOutY1 == 0.61)
    #expect(MeetPRMotion.easeOutX2 == 0.36)
    #expect(MeetPRMotion.easeOutY2 == 1.0)
    #expect(MeetPRMotion.springX1 == 0.34)
    #expect(MeetPRMotion.springY1 == 1.36)
    #expect(MeetPRMotion.springX2 == 0.64)
    #expect(MeetPRMotion.springY2 == 1.0)
    #expect(MeetPRMotion.rollX1 == 0.4)
    #expect(MeetPRMotion.rollY1 == 0)
    #expect(MeetPRMotion.rollX2 == 0.2)
    #expect(MeetPRMotion.rollY2 == 1.0)
    #expect(MeetPRMotion.screenX1 == 0.2)
    #expect(MeetPRMotion.screenY1 == 0.7)
    #expect(MeetPRMotion.screenX2 == 0.2)
    #expect(MeetPRMotion.screenY2 == 1.0)
    #expect(MeetPRMotion.sheetX1 == 0.2)
    #expect(MeetPRMotion.sheetY1 == 0.8)
    #expect(MeetPRMotion.sheetX2 == 0.2)
    #expect(MeetPRMotion.sheetY2 == 1.0)
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
