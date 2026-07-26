import SwiftUI

/// ⛔️ FROZEN v2 palette — compatibility quarantine, not a second standard.
///
/// These literals exist only so surfaces *outside* the black-gold-v3 wave
/// (coach side, auth shell) keep rendering exactly as they ship today; the
/// coach side has no v3 mockup yet, so remapping these to v3 tokens would
/// restyle it unreviewed. Never use these in new v3 work — new code reads the
/// `Color.MeetPR` v3 tokens above. Delete this file once the last legacy
/// consumer migrates (tracked in docs/design/handoff-v3/IMPL-PLAN.md).
extension Color.MeetPR {
  public static let brandRed = legacyRGB(229, 34, 30)
  public static let brandRedPress = legacyRGB(184, 26, 23)
  public static let brandRedSoft = Color(
    light: legacyRGB(229, 34, 30, opacity: 0.08),
    dark: legacyRGB(229, 34, 30, opacity: 0.12)
  )
  public static let green = legacyRGB(31, 179, 88)
  public static let greenSoft = legacyRGB(31, 179, 88, opacity: 0.14)
  public static let amber = legacyRGB(224, 168, 16)
  public static let amberSoft = legacyRGB(224, 168, 16, opacity: 0.14)
  // swiftlint:disable:next identifier_name
  public static let bg = Color(
    light: legacyRGB(250, 250, 250),
    dark: legacyRGB(0, 0, 0)
  )
  public static let surface1 = Color(
    light: legacyRGB(255, 255, 255),
    dark: legacyRGB(14, 14, 14)
  )
  public static let surface2 = Color(
    light: legacyRGB(244, 244, 245),
    dark: legacyRGB(22, 22, 22)
  )
  public static let surface3 = Color(
    light: legacyRGB(233, 233, 235),
    dark: legacyRGB(31, 31, 31)
  )
  public static let border = Color(
    light: legacyRGB(229, 229, 229),
    dark: legacyRGB(38, 38, 38)
  )
  public static let fgPrimary = Color(
    light: legacyRGB(10, 10, 10),
    dark: legacyRGB(255, 255, 255)
  )
  public static let fgSecondary = Color(
    light: legacyRGB(82, 82, 82),
    dark: legacyRGB(181, 181, 181)
  )
  public static let fgTertiary = Color(
    light: legacyRGB(163, 163, 163),
    dark: legacyRGB(115, 115, 115)
  )
  public static let fgDisabled = Color(
    light: legacyRGB(10, 10, 10, opacity: 0.35),
    dark: legacyRGB(255, 255, 255, opacity: 0.35)
  )

  private static func legacyRGB(
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
