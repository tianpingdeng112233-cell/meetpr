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

  public static let durationPress = 0.12
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
  public static let riseInitialDelay = 0.02
  public static let riseStagger = 0.04
  /// State A → B reveal on the training screen (§4.2): cards fan in after the
  /// hero settles.
  public static let recordingRevealDelay = 0.36
  public static let recordingRevealStagger = 0.09

  public static let press = Animation.easeInOut(duration: durationPress)
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

  // Migration aliases.
  public static let easeIOSX1 = easeOutX1
  public static let easeIOSY1 = easeOutY1
  public static let easeIOSX2 = easeOutX2
  public static let easeIOSY2 = easeOutY2
  public static let durationSlow = durationSheet
  public static let easeIOS = easeOut
}
