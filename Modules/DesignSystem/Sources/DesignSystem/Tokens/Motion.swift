import SwiftUI

@frozen public enum MeetPRMotion {
  public static let easeOutX1 = 0.22
  public static let easeOutY1 = 0.61
  public static let easeOutX2 = 0.36
  public static let easeOutY2 = 1.0

  public static let rollX1 = 0.4
  public static let rollY1 = 0.0
  public static let rollX2 = 0.2
  public static let rollY2 = 1.0

  public static let durationRollUp = 0.62
  public static let durationBloom = 0.75
  public static let durationStamp = 0.52
  public static let durationSpark = 0.80
  public static let durationShimmer = 4.50
  public static let durationHoldComplete = 1.10
  public static let durationHoldCancel = 0.30
  public static let sparkStagger = 0.018

  public static let completionSlideInitialDelay = 0.34
  public static let completionSlideStagger = 0.13
  public static let completionSlideDuration = 0.46
  public static let completionSlideOffset: CGFloat = 26
  public static let completionTickerDelay = 0.47
  public static let completionTickerDuration = 0.90
  public static let completionFadeDuration = 0.45

  public static func completionSlideDelay(_ index: Int) -> TimeInterval {
    completionSlideInitialDelay + Double(index) * completionSlideStagger
  }

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
}
