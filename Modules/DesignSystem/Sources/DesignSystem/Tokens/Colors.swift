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
  // swiftlint:disable:next type_body_length
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
    public static let gold300 = Color(
      light: rgb(252, 211, 77),
      dark: rgb(255, 212, 112)
    )
    public static let gold200 = Color(
      light: rgb(254, 243, 199),
      dark: rgb(255, 226, 142)
    )
    public static let gold700 = Color(
      light: rgb(180, 83, 9),
      dark: rgb(184, 120, 20)
    )
    public static let gold800 = Color(
      light: rgb(154, 68, 6),
      dark: rgb(154, 100, 19)
    )
    public static let gold900 = Color(
      light: rgb(124, 54, 5),
      dark: rgb(122, 78, 14)
    )
    /// Muted gold used for de-emphasized numerals on gold surfaces.
    public static let goldMuted = Color(
      light: rgb(180, 83, 9),
      dark: rgb(184, 147, 90)
    )
    public static let goldGradientStart = Color(
      light: rgb(217, 119, 6),
      dark: rgb(224, 143, 15)
    )
    public static let goldGradientEnd = Color(
      light: rgb(245, 185, 60),
      dark: rgb(255, 201, 60)
    )

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
    /// The active-exercise card. Dark sinks it *below* the page (`#0F0F12`) to
    /// let the gold edge read as a light source; light floats it as a plain
    /// white card. Neither is `surfaceCard`, so it gets its own token.
    public static let surfaceFocus = Color(
      light: rgb(255, 255, 255),
      dark: rgb(15, 15, 18)
    )
    /// Track behind the long-press fill, read against whichever fill the
    /// primary CTA uses: warm-dark on the gold CTA, navy on the light CTA.
    public static let holdTrack = Color(
      light: rgb(31, 41, 55),
      dark: rgb(23, 18, 10)
    )
    public static let medalInset = Color(
      light: rgb(254, 243, 199),
      dark: rgb(23, 18, 10)
    )

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
    /// Hairline around inner controls (segmented keys, inset tables).
    public static let borderControl = Color(
      light: rgb(229, 231, 235),
      dark: rgb(42, 42, 46)
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
      light: rgb(107, 114, 128),
      dark: rgb(161, 161, 166)
    )
    public static let textMuted = Color(
      light: rgb(107, 114, 128),
      dark: rgb(138, 138, 144)
    )
    public static let textFaint = Color(
      light: rgb(156, 163, 175),
      dark: rgb(122, 122, 128)
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
    public static let displayText = Color(
      light: rgb(17, 24, 39),
      dark: rgb(243, 243, 246)
    )
    public static let coachNoteText = Color(
      light: rgb(75, 85, 99),
      dark: rgb(196, 196, 200)
    )
    /// Emphasized body copy — one step heavier than `textSecondary`.
    public static let bodyStrong = Color(
      light: rgb(31, 41, 55),
      dark: rgb(228, 228, 230)
    )
    /// Micro labels: table headers, chart axes, legends.
    public static let microLabel = Color(
      light: rgb(156, 163, 175),
      dark: rgb(106, 106, 112)
    )
    /// Numerals for a set that has not been logged yet.
    public static let pendingText = Color(
      light: rgb(156, 163, 175),
      dark: rgb(90, 90, 96)
    )
    /// Ring around the not-yet-completed set marker.
    public static let pendingRing = Color(
      light: rgb(209, 213, 219),
      dark: rgb(74, 74, 80)
    )

    // MARK: - Semantic

    public static let success = Color(
      light: rgb(21, 128, 61),
      dark: rgb(94, 158, 120)
    )
    public static let danger = rgb(229, 72, 77)
    /// Unread badges keep the platform alert red in both themes; the mockups
    /// use it verbatim rather than the softer `danger` used for failed sets.
    public static let unread = rgb(255, 59, 48)
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
    /// Secondary line inside the primary CTA. The themes do not agree here:
    /// dark writes muted ink on the gold fill, light writes amber on the navy
    /// fill. Reusing `inkOnGold` for both makes the light subtitle invisible.
    public static let ctaTextSecondary = Color(
      light: rgb(245, 158, 11),
      dark: rgb(20, 20, 20, opacity: 0.72)
    )
    /// Ambient cast under the primary CTA: a gold halo on dark, a neutral navy
    /// drop shadow on light (the light mockups redefine the glow keyframe to
    /// `0 6px 18px rgba(17,24,39,.22)`).
    public static let ctaGlow = Color(
      light: rgb(17, 24, 39, opacity: 0.22),
      dark: rgb(245, 166, 35, opacity: 0.38)
    )

    /// `rgba(17,24,39,.06)` — the light theme's card shadow. Dark never casts
    /// one (it separates surfaces with a hairline instead), so this is only
    /// ever read through ``MeetPRCardSurface``.
    public static let cardShadow = rgb(17, 24, 39, opacity: 0.06)
    public static let modalShadow = Color(
      light: rgb(17, 24, 39, opacity: 0.18),
      dark: rgb(0, 0, 0, opacity: 0.5)
    )

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
      light: rgb(156, 163, 175),
      dark: rgb(106, 106, 112)
    )

    // MARK: - Component palettes

    public static let ctaTopHighlight = rgb(255, 255, 255)
    /// Inner bottom shade of the primary CTA: warm brown under gold, plain
    /// black under the light theme's navy fill.
    public static let ctaBottomShade = Color(
      light: rgb(0, 0, 0),
      dark: rgb(120, 60, 0)
    )
    public static let shimmerHighlight = Color(
      light: rgb(255, 255, 255),
      dark: rgb(255, 224, 160)
    )
    public static let chatBubbleOutgoing = Color(
      light: rgb(17, 24, 39),
      dark: rgb(231, 231, 233)
    )
    public static let chatBubbleIncoming = Color(
      light: rgb(255, 255, 255),
      dark: rgb(27, 27, 30)
    )
    public static let celebrationBloom = Color(
      light: rgb(245, 158, 11),
      dark: rgb(255, 220, 140)
    )
    public static let celebrationSpark = Color(
      light: rgb(251, 191, 62),
      dark: rgb(255, 233, 168)
    )
    public static let celebrationMedalBottom = Color(
      light: rgb(180, 83, 9),
      dark: rgb(201, 138, 24)
    )
    public static let celebrationRibbonStart = Color(
      light: rgb(217, 119, 6),
      dark: rgb(216, 146, 38)
    )

    public static let plate25 = rgb(217, 38, 38)
    public static let plate20 = rgb(38, 77, 204)
    public static let plate15 = rgb(242, 204, 26)
    public static let plate10 = rgb(38, 153, 77)

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
