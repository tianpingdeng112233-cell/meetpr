import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif

#if canImport(UIKit)
  import UIKit
#endif

extension Color {
  public init(light: Color, dark: Color) {
    #if canImport(UIKit)
      self = Color(
        UIColor { traits in
          traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        }
      )
    #elseif canImport(AppKit)
      self = Color(
        NSColor(name: nil) { appearance in
          let match = appearance.bestMatch(from: [.darkAqua, .aqua])
          return match == .darkAqua ? NSColor(dark) : NSColor(light)
        }
      )
    #else
      self = dark
    #endif
  }
}

extension Color {
  public enum MeetPR {
    // MARK: - Brand gold

    public static let goldCTA = Color(
      light: rgb(180, 83, 9),
      dark: rgb(255, 184, 0)
    )
    public static let gold500 = Color(
      light: rgb(217, 119, 6),
      dark: rgb(245, 166, 35)
    )
    public static let gold400 = Color(
      light: rgb(245, 158, 11),
      dark: rgb(251, 191, 62)
    )
    /// `#FFD470` — hero-bar gradient top, hard-coded in the mockup for both themes.
    public static let gold300 = rgb(255, 212, 112)
    public static let gold200 = Color(
      light: rgb(254, 243, 199),
      dark: rgb(255, 226, 142)
    )
    /// `--gold-rgb`; kept as a color so callers can apply SwiftUI opacity.
    public static let goldRGB = gold500
    public static let goldText = Color(
      light: rgb(154, 74, 6),
      dark: rgb(245, 166, 35)
    )
    /// `#B8791A` — right medal-ribbon gradient start; SVG literal, both themes.
    public static let gold700 = rgb(184, 121, 26)
    /// `#9A6413` — left medal-ribbon gradient end; SVG literal, both themes.
    public static let gold800 = rgb(154, 100, 19)
    /// `#7A4E0E` — right medal-ribbon gradient end; SVG literal, both themes.
    public static let gold900 = rgb(122, 78, 14)
    /// `#B8935A` — review sheet's 总容量 eyebrow; mockup literal, both themes.
    public static let goldMuted = rgb(184, 147, 90)
    public static let goldGradientStart = Color(
      light: rgb(217, 119, 6),
      dark: rgb(224, 143, 15)
    )
    public static let goldGradientEnd = Color(
      light: rgb(245, 185, 60),
      dark: rgb(255, 201, 60)
    )
    /// `#A9731C` — deep end of the volume-bar gradient (`volGrad`) and the
    /// E1RM-vs-1RM comparison bars; mockup literal, both themes.
    public static let goldBarDeep = rgb(169, 115, 28)

    // MARK: - Surfaces

    public static let bgBase = Color(
      light: rgb(245, 246, 248),
      dark: rgb(10, 10, 12)
    )
    public static let bgInset = Color(
      light: rgb(250, 250, 251),
      dark: rgb(16, 16, 20)
    )
    public static let bgStack = Color(
      light: rgb(238, 240, 243),
      dark: rgb(18, 18, 23)
    )
    public static let surfaceCard = Color(
      light: rgb(255, 255, 255),
      dark: rgb(20, 20, 22)
    )
    public static let surfaceElevated = Color(
      light: rgb(255, 255, 255),
      dark: rgb(22, 22, 24)
    )
    public static let surfaceKey = Color(
      light: rgb(243, 244, 246),
      dark: rgb(28, 28, 32)
    )
    /// Surface for a card sitting on another card (`--surface-raised`).
    public static let surfaceRaised = Color(
      light: rgb(238, 240, 243),
      dark: rgb(35, 35, 39)
    )
    /// `rgba(15,15,18,.97)` — the morphing ghost pill in the CTA→training
    /// transition; mockup literal, both themes (opacity applied at call site).
    public static let surfaceFocus = rgb(15, 15, 18)
    /// `#17120A` — the long-press "complete workout" button fill; mockup
    /// literal, both themes.
    public static let holdTrack = rgb(23, 18, 10)
    /// `#17120A` at 0.92 — the medal's inner disc; SVG literal, both themes.
    public static let medalInset = rgb(23, 18, 10)

    // MARK: - Borders

    public static let borderHairline = Color(
      light: rgb(233, 235, 238),
      dark: rgb(23, 23, 26)
    )
    public static let borderSubtle = Color(
      light: rgb(229, 231, 235),
      dark: rgb(30, 30, 34)
    )
    public static let borderDefault = Color(
      light: rgb(229, 231, 235),
      dark: rgb(38, 38, 41)
    )
    public static let borderStrong = Color(
      light: rgb(209, 213, 219),
      dark: rgb(46, 46, 50)
    )

    // MARK: - Text

    public static let textPrimary = Color(
      light: rgb(17, 24, 39),
      dark: rgb(237, 237, 237)
    )
    public static let textSecondary = Color(
      light: rgb(75, 85, 99),
      dark: rgb(200, 200, 204)
    )
    public static let textTertiary = Color(
      light: rgb(92, 99, 113),
      dark: rgb(161, 161, 166)
    )
    public static let textMuted = Color(
      light: rgb(92, 99, 113),
      dark: rgb(138, 138, 144)
    )
    public static let textFaint = Color(
      light: rgb(92, 99, 113),
      dark: rgb(138, 138, 144)
    )
    public static let textDisabled = Color(
      light: rgb(156, 163, 175),
      dark: rgb(85, 85, 92)
    )
    /// Skeleton / placeholder blocks (`--text-ghost`).
    public static let textGhost = Color(
      light: rgb(209, 213, 219),
      dark: rgb(62, 62, 68)
    )
    public static let coachNoteText = Color(
      light: rgb(75, 85, 99),
      dark: rgb(196, 196, 200)
    )

    // MARK: - Semantic

    public static let success = Color(
      light: rgb(21, 128, 61),
      dark: rgb(94, 158, 120)
    )
    /// `--success-rgb`; kept as a color so callers can apply SwiftUI opacity.
    public static let successRGB = success
    public static let danger = rgb(229, 72, 77)
    /// `--danger-rgb`; kept as a color so callers can apply SwiftUI opacity.
    public static let dangerRGB = danger
    public static let dangerMuted = Color(
      light: rgb(163, 59, 64),
      dark: rgb(200, 136, 136)
    )
    public static let dangerFill = rgb(192, 52, 58)
    /// Unread count badges ride `--danger-fill`, exactly like the mockup's
    /// message-bubble badges; both themes share the value.
    public static let unread = dangerFill
    public static let chartLine = Color(
      light: rgb(154, 164, 176),
      dark: rgb(220, 227, 234)
    )
    public static let inkOnGold = Color(
      light: rgb(255, 255, 255),
      dark: rgb(20, 20, 20)
    )
    public static let ctaBackground = Color(
      light: rgb(17, 24, 39),
      dark: rgb(255, 184, 0)
    )
    public static let ctaText = Color(
      light: rgb(255, 255, 255),
      dark: rgb(20, 20, 20)
    )
    public static let ctaFill = rgb(17, 24, 39)

    /// `rgba(17,24,39,.06)` — the light theme's card shadow. Dark never casts
    /// one (it separates surfaces with a hairline instead), so this is only
    /// ever read through ``MeetPRCardSurface``.
    public static let cardShadow = Color(
      light: rgb(17, 24, 39, opacity: 0.06),
      dark: .clear
    )
    /// `0 30px 60px rgba(0,0,0,.5)` — the postpone dialog's shadow; mockup
    /// literal, both themes (geometry lives in ``MeetPRCardSurface``).
    public static let modalShadow = rgb(0, 0, 0, opacity: 0.5)

    public static let goldSoft = gold500.opacity(0.14)
    /// `--success-soft`: a lighter success *tone* (text/icons), per theme.
    public static let successSoft = Color(
      light: rgb(21, 128, 61),
      dark: rgb(159, 199, 174)
    )
    /// Translucent success fill for backgrounds (the old successSoft role).
    public static let successTint = success.opacity(0.14)
    public static let dangerSoft = danger.opacity(0.14)
    /// `--bg-deep`: the layer beneath the page (sheet backdrops).
    public static let bgDeep = Color(
      light: rgb(237, 238, 241),
      dark: rgb(5, 5, 6)
    )
    /// `--text-dim`: not-yet-done state text.
    public static let textDim = Color(
      light: rgb(92, 99, 113),
      dark: rgb(138, 138, 144)
    )

    // MARK: - CSS aliases and mockup shell

    public static let textBody = textSecondary
    public static let textHeading = textPrimary
    public static let accent = gold500
    public static let bezel = rgb(28, 28, 30)
    public static let bezelEdge = rgb(42, 42, 45)
    public static let desk1 = Color(
      light: rgb(233, 233, 238),
      dark: rgb(26, 26, 30)
    )
    public static let desk2 = Color(
      light: rgb(210, 210, 217),
      dark: rgb(5, 5, 6)
    )

    // MARK: - Component palettes

    public static let ctaTopHighlight = rgb(255, 255, 255)
    /// Inner bottom shade of the primary CTA: warm brown under gold, plain
    /// black under the light theme's navy fill.
    public static let ctaBottomShade = Color(
      light: rgb(0, 0, 0),
      dark: rgb(120, 60, 0)
    )
    /// `rgba(255,224,160,.42)` — the CTA sweep highlight; mockup literal.
    /// `.theme-light` hides the shimmer entirely, so no light variant exists.
    public static let shimmerHighlight = rgb(255, 224, 160)
    /// `#FFDC8C` — celebration bloom core; mockup literal, both themes.
    public static let celebrationBloom = rgb(255, 220, 140)
    /// `#FFE9A8` — the brighter 1-in-3 celebration spark; mockup literal.
    public static let celebrationSpark = rgb(255, 233, 168)
    /// `#C98A18` — medal disc gradient bottom stop; SVG literal, both themes.
    public static let celebrationMedalBottom = rgb(201, 138, 24)
    /// `#D89226` — left medal-ribbon gradient start; SVG literal, both themes.
    public static let celebrationRibbonStart = rgb(216, 146, 38)

    public static func rpeScale(
      red: Double,
      green: Double,
      blue: Double
    ) -> Color {
      rgb(red, green, blue)
    }

    private static func rgb(
      _ red: Double,
      _ green: Double,
      _ blue: Double,
      opacity: Double = 1
    ) -> Color {
      Color(
        red: red / 255,
        green: green / 255,
        blue: blue / 255,
        opacity: opacity
      )
    }
  }
}
