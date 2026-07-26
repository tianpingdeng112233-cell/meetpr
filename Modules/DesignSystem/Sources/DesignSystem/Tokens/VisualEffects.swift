import SwiftUI

/// A lossless Swift representation of one CSS `box-shadow` layer.
public struct MeetPRShadowToken: Sendable {
  public let color: Color
  public let offsetX: CGFloat
  public let offsetY: CGFloat
  public let blur: CGFloat
  public let spread: CGFloat
  public let isInset: Bool

  public init(
    color: Color,
    offsetX: CGFloat,
    offsetY: CGFloat,
    blur: CGFloat,
    spread: CGFloat = 0,
    isInset: Bool = false
  ) {
    self.color = color
    self.offsetX = offsetX
    self.offsetY = offsetY
    self.blur = blur
    self.spread = spread
    self.isInset = isInset
  }

  /// CSS blur radius is twice SwiftUI's shadow radius.
  public var swiftUIRadius: CGFloat { blur / 2 }
}

public enum MeetPRVisualEffects {
  /// `--cta-mold`.
  public static func ctaMold(for colorScheme: ColorScheme) -> [MeetPRShadowToken] {
    if colorScheme == .light {
      return [
        MeetPRShadowToken(
          color: Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255).opacity(0.18),
          offsetX: 0,
          offsetY: 6,
          blur: 20
        )
      ]
    }

    return [
      MeetPRShadowToken(
        color: .white.opacity(0.55),
        offsetX: 0,
        offsetY: 1.5,
        blur: 0,
        isInset: true
      ),
      MeetPRShadowToken(
        color: Color(red: 120 / 255, green: 60 / 255, blue: 0).opacity(0.25),
        offsetX: 0,
        offsetY: -2,
        blur: 3,
        isInset: true
      ),
      MeetPRShadowToken(
        color: Color.MeetPR.goldRGB.opacity(0.38),
        offsetX: 0,
        offsetY: 8,
        blur: 26
      ),
    ]
  }

  /// `--cta-mold-held`.
  public static func ctaMoldHeld(for colorScheme: ColorScheme) -> [MeetPRShadowToken] {
    if colorScheme == .light {
      return [
        MeetPRShadowToken(
          color: Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255).opacity(0.14),
          offsetX: 0,
          offsetY: 0,
          blur: 0,
          spread: 4
        )
      ]
    }

    return [
      MeetPRShadowToken(
        color: .white.opacity(0.55),
        offsetX: 0,
        offsetY: 1.5,
        blur: 0,
        isInset: true
      ),
      MeetPRShadowToken(
        color: Color(red: 120 / 255, green: 60 / 255, blue: 0).opacity(0.25),
        offsetX: 0,
        offsetY: -2,
        blur: 3,
        isInset: true
      ),
      MeetPRShadowToken(
        color: Color.MeetPR.goldRGB.opacity(0.28),
        offsetX: 0,
        offsetY: 0,
        blur: 0,
        spread: 4
      ),
      MeetPRShadowToken(
        color: Color.MeetPR.goldRGB.opacity(0.45),
        offsetX: 0,
        offsetY: 0,
        blur: 30
      ),
    ]
  }

  /// `--headline-emboss`.
  public static func headlineEmboss(for colorScheme: ColorScheme) -> [MeetPRShadowToken] {
    if colorScheme == .light {
      return [
        MeetPRShadowToken(
          color: .white.opacity(0.9),
          offsetX: 0,
          offsetY: 1,
          blur: 0
        ),
        MeetPRShadowToken(
          color: Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255).opacity(0.14),
          offsetX: 0,
          offsetY: 2,
          blur: 4
        ),
      ]
    }

    return [
      MeetPRShadowToken(color: .black, offsetX: 0, offsetY: 2, blur: 0),
      MeetPRShadowToken(color: .black.opacity(0.55), offsetX: 0, offsetY: 3, blur: 3),
      MeetPRShadowToken(
        color: .white.opacity(0.22),
        offsetX: 0,
        offsetY: -1,
        blur: 0
      ),
    ]
  }
}
