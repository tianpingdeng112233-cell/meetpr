import SwiftUI

@frozen public enum MeetPRMotion {
  public static let easeOutX1 = 0.2
  public static let easeOutY1 = 0.7
  public static let easeOutX2 = 0.2
  public static let easeOutY2 = 1.0

  public static let sheetX1 = 0.2
  public static let sheetY1 = 0.8
  public static let sheetX2 = 0.2
  public static let sheetY2 = 1.0

  public static let riseX1 = 0.215
  public static let riseY1 = 0.61
  public static let riseX2 = 0.355
  public static let riseY2 = 1.0

  public static let durationPress = 0.12
  public static let durationFast = 0.20
  public static let durationScreen = 0.28
  public static let durationSheet = 0.34
  public static let durationPill = 0.34
  public static let durationRise = 0.50
  public static let durationRollUp = 0.98
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
    easeOutX1,
    easeOutY1,
    easeOutX2,
    easeOutY2,
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
    riseX1,
    riseY1,
    riseX2,
    riseY2,
    duration: durationRise
  )
  public static let pillSelect = Animation.timingCurve(
    sheetX1,
    sheetY1,
    sheetX2,
    sheetY2,
    duration: durationPill
  )

  // Migration aliases.
  public static let easeIOSX1 = easeOutX1
  public static let easeIOSY1 = easeOutY1
  public static let easeIOSX2 = easeOutX2
  public static let easeIOSY2 = easeOutY2
  public static let durationBase = durationScreen
  public static let durationSlow = durationSheet
  public static let easeIOS = screen
}
