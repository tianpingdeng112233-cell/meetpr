import SwiftUI

enum MeetPRFontMetrics {
  static let displayHeroSize: CGFloat = 44
  static let title1Size: CGFloat = 34
  static let title2Size: CGFloat = 28
  static let headlineSize: CGFloat = 20
  static let bodySize: CGFloat = 17
  static let footnoteSize: CGFloat = 13
  static let captionSize: CGFloat = 11
  static let monoLabelSize: CGFloat = 12
  static let displayNumeralSize: CGFloat = 60
  static let displayUnitSize: CGFloat = 24

  static let monoLabelTracking: CGFloat = 0.96
  static let displayUnitTracking: CGFloat = 0.96
}

extension Font {
  public enum MeetPR {
    public static let displayHero = Font.system(size: 44, weight: .bold).leading(.tight)
    public static let title1 = Font.system(size: 34, weight: .bold).leading(.tight)
    public static let title2 = Font.system(size: 28, weight: .bold)
    public static let headline = Font.system(size: 20, weight: .semibold)
    public static let body = Font.system(size: 17, weight: .regular)
    public static let bodyEmphasis = Font.system(size: 17, weight: .semibold)
    public static let footnote = Font.system(size: 13, weight: .regular)
    public static let caption = Font.system(size: 11, weight: .medium)
    public static let monoLabel = Font.system(size: 12, weight: .medium, design: .monospaced)
    public static let displayNumeral = Font.system(size: 60, weight: .heavy).monospacedDigit()
    public static let displayUnit = Font.system(size: 24, weight: .heavy)

    public static let monoLabelTracking = MeetPRFontMetrics.monoLabelTracking
    public static let displayUnitTracking = MeetPRFontMetrics.displayUnitTracking
  }
}
