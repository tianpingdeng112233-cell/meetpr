import SwiftUI

@frozen public enum MeetPRMotion {
  public static let easeIOSX1 = 0.32
  public static let easeIOSY1 = 0.72
  public static let easeIOSX2 = 0.0
  public static let easeIOSY2 = 1.0

  public static let durationFast: Double = 0.20
  public static let durationBase: Double = 0.24
  public static let durationSlow: Double = 0.28

  public static let easeIOS = Animation.timingCurve(
    easeIOSX1,
    easeIOSY1,
    easeIOSX2,
    easeIOSY2,
    duration: durationBase
  )
}
