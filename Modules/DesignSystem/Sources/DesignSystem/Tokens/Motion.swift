import SwiftUI

@frozen public enum MeetPRMotion {
  public static let easeOutX1 = 0.22
  public static let easeOutY1 = 0.61
  public static let easeOutX2 = 0.36
  public static let easeOutY2 = 1.0

  public static let springX1 = 0.34
  public static let springY1 = 1.36
  public static let springX2 = 0.64
  public static let springY2 = 1.0

  public static let rollX1 = 0.4
  public static let rollY1 = 0.0
  public static let rollX2 = 0.2
  public static let rollY2 = 1.0

  public static let screenX1 = 0.2
  public static let screenY1 = 0.7
  public static let screenX2 = 0.2
  public static let screenY2 = 1.0

  public static let sheetX1 = 0.2
  public static let sheetY1 = 0.8
  public static let sheetX2 = 0.2
  public static let sheetY2 = 1.0

  // motion/01 lines 38, 40-41: every held-state transition is `.13s ease`.
  public static let durationPress = 0.13
  public static let durationFast = 0.20
  public static let durationBase = 0.24
  public static let durationScreen = 0.28
  public static let durationSheet = 0.34
  public static let durationPill = 0.34
  public static let durationRise = 0.50
  public static let durationRollUp = 0.62
  public static let durationBloom = 0.75
  public static let durationStamp = 0.52
  public static let durationSpark = 0.80
  public static let durationGlow = 4.20
  public static let durationShimmer = 4.50
  public static let durationHoldComplete = 1.10
  public static let durationHoldCancel = 0.30
  public static let sparkStagger = 0.018
  // motion/04 lines 28-35: riseIn defaults to base 20ms and step 40ms.
  public static let riseInitialDelay = 0.02
  public static let riseStagger = 0.04
  // motion/04 lines 28-35: every direct child runs for 500ms from y=72,
  // scaleY=.88 and opacity=0 through the exact easeOutCubic equation.
  public static let riseInitialOffset: CGFloat = 72
  public static let riseInitialScaleY: CGFloat = 0.88
  // motion/04 lines 98-99: the recording cards use base 360ms / step 90ms.
  public static let recordingRevealDelay = 0.36
  public static let recordingRevealStagger = 0.09
  // motion/04 line 107: sticky pill enters for 340ms from y=-9, scaleY=.62.
  public static let pillInitialOffset: CGFloat = -9
  public static let pillInitialScaleY: CGFloat = 0.62

  // motion/01 lines 92-112: CTA launch timing and geometry.
  public static let launchExitDuration = 0.20
  public static let launchSwitchDelay = 0.14
  public static let launchDestinationFadeDuration = 0.28
  public static let launchMorphDuration = 0.42
  public static let launchGhostFadeDuration = 0.20
  public static let launchSourceCornerRadius: CGFloat = 28
  public static let launchDestinationCornerRadius: CGFloat = 16
  public static let launchExitOffset: CGFloat = 26
  // motion/01 lines 107-110: hero children rise 9pt for 220ms, 55ms apart.
  public static let launchHeroChildDuration = 0.22
  public static let launchHeroChildStagger = 0.055
  public static let launchHeroChildOffset: CGFloat = 9

  // motion/02 lines 68-78: feedback DOM swap and exact tween schedule.
  public static let feedbackPreviewFadeDuration = 0.05
  public static let feedbackExpandDuration = 0.38
  public static let feedbackCollapseDuration = 0.28
  public static let feedbackItemDuration = 0.20
  public static let feedbackItemInitialDelay = 0.02
  public static let feedbackItemStagger = 0.03
  public static let feedbackItemOffset: CGFloat = -8
  public static let feedbackArrowDuration = 0.26
  public static let feedbackPreviewReturnDelay = 0.09
  public static let feedbackPreviewReturnDuration = 0.18
  public static let feedbackOvershootStart = 0.62
  public static let feedbackOvershoot = 3.0

  // motion/05 lines 65-70: completion slide/fade/ticker schedule.
  public static let completionSlideInitialDelay = 0.34
  public static let completionSlideStagger = 0.13
  public static let completionSlideDuration = 0.46
  public static let completionSlideOffset: CGFloat = 26
  public static let completionTickerDelay = 0.47

  /// motion/05 line 65: each data-slide waits 340+i×130ms.
  public static func completionSlideDelay(_ index: Int) -> TimeInterval {
    completionSlideInitialDelay + Double(index) * completionSlideStagger
  }

  public static let completionTickerDuration = 0.90
  public static let completionFadeDuration = 0.45

  // CSS `ease` from motion/01 line 38 is cubic-bezier(.25,.1,.25,1).
  public static let press = Animation.timingCurve(
    0.25,
    0.1,
    0.25,
    1,
    duration: durationPress
  )
  public static let screen = Animation.timingCurve(
    screenX1,
    screenY1,
    screenX2,
    screenY2,
    duration: durationScreen
  )
  public static let sheet = Animation.timingCurve(
    sheetX1,
    sheetY1,
    sheetX2,
    sheetY2,
    duration: durationSheet
  )
  public static let rise = Animation.timingCurve(
    easeOutX1,
    easeOutY1,
    easeOutX2,
    easeOutY2,
    duration: durationRise
  )
  public static let pillSelect = Animation.timingCurve(
    sheetX1,
    sheetY1,
    sheetX2,
    sheetY2,
    duration: durationPill
  )
  public static let pillRise = Animation.timingCurve(
    easeOutX1,
    easeOutY1,
    easeOutX2,
    easeOutY2,
    duration: durationPill
  )
  public static let easeOut = Animation.timingCurve(
    easeOutX1,
    easeOutY1,
    easeOutX2,
    easeOutY2,
    duration: durationBase
  )
  public static let spring = Animation.timingCurve(
    springX1,
    springY1,
    springX2,
    springY2,
    duration: durationSheet
  )
  public static let rollUp = Animation.timingCurve(
    rollX1,
    rollY1,
    rollX2,
    rollY2,
    duration: durationRollUp
  )

  public static func easeOutCubic(_ progress: Double) -> Double {
    1 - pow(1 - progress, 3)
  }

  public static func easeOutQuart(_ progress: Double) -> Double {
    1 - pow(1 - progress, 4)
  }

  public static func feedbackHeightProgress(_ progress: Double) -> Double {
    let clamped = min(max(progress, 0), 1)
    return easeOutCubic(clamped)
  }

  public static func feedbackOvershoot(at progress: Double) -> Double {
    let clamped = min(max(progress, 0), 1)
    guard clamped > feedbackOvershootStart else { return 0 }
    let local = (clamped - feedbackOvershootStart) / (1 - feedbackOvershootStart)
    return feedbackOvershoot * sin(local * .pi)
  }

  // Migration aliases.
  public static let easeIOSX1 = easeOutX1
  public static let easeIOSY1 = easeOutY1
  public static let easeIOSX2 = easeOutX2
  public static let easeIOSY2 = easeOutY2
  public static let durationSlow = durationSheet
  public static let easeIOS = easeOut
}
