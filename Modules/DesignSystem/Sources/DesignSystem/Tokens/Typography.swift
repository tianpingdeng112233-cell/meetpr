import SwiftUI

public enum MeetPRFontMetrics {
  public static let size8: CGFloat = 8
  public static let size9: CGFloat = 9
  public static let size10: CGFloat = 10
  public static let size11: CGFloat = 11
  public static let size12: CGFloat = 12
  public static let size13: CGFloat = 13
  public static let size14: CGFloat = 14
  public static let size15: CGFloat = 15
  public static let size16: CGFloat = 16
  public static let size17: CGFloat = 17
  public static let size18: CGFloat = 18
  public static let size19: CGFloat = 19
  public static let size20: CGFloat = 20
  public static let size21: CGFloat = 21
  public static let size22: CGFloat = 22
  public static let size23: CGFloat = 23
  public static let size24: CGFloat = 24
  public static let size26: CGFloat = 26
  public static let size27: CGFloat = 27
  public static let size28: CGFloat = 28
  public static let size30: CGFloat = 30
  public static let size32: CGFloat = 32
  public static let size34: CGFloat = 34
  public static let size36: CGFloat = 36
  public static let size38: CGFloat = 38
  public static let size40: CGFloat = 40
  public static let size44: CGFloat = 44
  public static let size46: CGFloat = 46
  public static let size48: CGFloat = 48
  public static let size50: CGFloat = 50
  public static let size54: CGFloat = 54
  public static let size64: CGFloat = 64

  public static let displayHeroSize = size54
  public static let title1Size = size34
  public static let title2Size = size28
  public static let headlineSize = size20
  public static let bodySize = size17
  public static let footnoteSize = size13
  public static let captionSize = size11
  public static let monoLabelSize = size12
  public static let displayNumeralSize = size54
  public static let displayUnitSize = size24

  public static let monoLabelTracking: CGFloat = 0.6
  public static let displayUnitTracking: CGFloat = 0.8
}

extension Font {
  public enum MeetPRDisplayWeight: Sendable {
    case extraBold
    case black
  }

  public enum MeetPRMonoWeight: Sendable {
    case regular
    case medium
    case semibold
    case bold
  }

  public enum MeetPRBodyWeight: Sendable {
    case regular
    case medium
    case semibold
    case bold
  }

  public enum MeetPR {
    public static func system(
      size: CGFloat,
      weight: Font.Weight = .regular,
      design: Font.Design = .default
    ) -> Font {
      .system(size: size, weight: weight, design: design)
    }

    public static func display(
      size: CGFloat,
      weight: MeetPRDisplayWeight = .extraBold
    ) -> Font {
      switch weight {
      case .extraBold:
        MeetPRFontFamily.font(
          named: MeetPRFontFamily.archivoExtraBold,
          size: size,
          fallbackWeight: .heavy
        )
      case .black:
        MeetPRFontFamily.font(
          named: MeetPRFontFamily.archivoBlack,
          size: size,
          fallbackWeight: .black
        )
      }
    }

    public static func mono(
      size: CGFloat,
      weight: MeetPRMonoWeight = .regular
    ) -> Font {
      let name: String
      let fallbackWeight: Font.Weight
      switch weight {
      case .regular:
        name = MeetPRFontFamily.ibmPlexMonoRegular
        fallbackWeight = .regular
      case .medium:
        name = MeetPRFontFamily.ibmPlexMonoMedium
        fallbackWeight = .medium
      case .semibold:
        name = MeetPRFontFamily.ibmPlexMonoSemibold
        fallbackWeight = .semibold
      case .bold:
        name = MeetPRFontFamily.ibmPlexMonoBold
        fallbackWeight = .bold
      }
      return MeetPRFontFamily.font(
        named: name,
        size: size,
        fallbackWeight: fallbackWeight,
        design: .monospaced
      )
    }

    public static func body(
      size: CGFloat,
      weight: MeetPRBodyWeight = .regular
    ) -> Font {
      let name: String
      let fallbackWeight: Font.Weight
      switch weight {
      case .regular:
        name = MeetPRFontFamily.ibmPlexSansRegular
        fallbackWeight = .regular
      case .medium:
        name = MeetPRFontFamily.ibmPlexSansMedium
        fallbackWeight = .medium
      case .semibold:
        name = MeetPRFontFamily.ibmPlexSansSemibold
        fallbackWeight = .semibold
      case .bold:
        name = MeetPRFontFamily.ibmPlexSansBold
        fallbackWeight = .bold
      }
      return MeetPRFontFamily.font(
        named: name,
        size: size,
        fallbackWeight: fallbackWeight
      )
    }

    public static let displayHero = display(size: MeetPRFontMetrics.displayHeroSize)
    public static let title1 = display(size: MeetPRFontMetrics.title1Size)
    public static let title2 = display(size: MeetPRFontMetrics.title2Size)
    public static let headline = display(size: MeetPRFontMetrics.headlineSize)
    public static let body = body(size: MeetPRFontMetrics.bodySize)
    public static let bodyEmphasis = body(
      size: MeetPRFontMetrics.bodySize,
      weight: .semibold
    )
    public static let footnote = body(size: MeetPRFontMetrics.footnoteSize)
    public static let caption = body(
      size: MeetPRFontMetrics.captionSize,
      weight: .medium
    )
    public static let monoLabel = mono(
      size: MeetPRFontMetrics.monoLabelSize,
      weight: .semibold
    )
    public static let displayNumeral = display(size: MeetPRFontMetrics.displayNumeralSize)
    public static let displayUnit = mono(
      size: MeetPRFontMetrics.displayUnitSize,
      weight: .bold
    )

    public static let monoLabelTracking = MeetPRFontMetrics.monoLabelTracking
    public static let displayUnitTracking = MeetPRFontMetrics.displayUnitTracking
  }
}
