import SwiftUI
import Testing

@testable import DesignSystem

#if canImport(AppKit)
  import AppKit
#endif

#if canImport(UIKit)
  import UIKit
#endif

private struct ColorComponents: Sendable {
  let red: Double
  let green: Double
  let blue: Double
  let alpha: Double

  init(_ red: Double, _ green: Double, _ blue: Double, alpha: Double = 1) {
    self.red = red > 1 ? red / 255 : red
    self.green = green > 1 ? green / 255 : green
    self.blue = blue > 1 ? blue / 255 : blue
    self.alpha = alpha
  }
}

private enum ColorTestError: Error {
  case unsupportedPlatform
  case unresolvedColor
}

@Suite("MeetPR black-gold color tokens")
struct ColorsTests {
  @Test("surface tokens match both v3 themes")
  func surfaceTokensMatchBothThemes() throws {
    try assertDynamicColor(.MeetPR.bgDeep, dark: .init(5, 5, 6), light: .init(237, 238, 241))
    try assertDynamicColor(.MeetPR.bgBase, dark: .init(10, 10, 12), light: .init(245, 246, 248))
    try assertDynamicColor(.MeetPR.bgInset, dark: .init(16, 16, 20), light: .init(250, 250, 251))
    try assertDynamicColor(.MeetPR.bgStack, dark: .init(18, 18, 23), light: .init(238, 240, 243))
    try assertDynamicColor(
      .MeetPR.surfaceCard,
      dark: .init(20, 20, 22),
      light: .init(255, 255, 255)
    )
    try assertDynamicColor(
      .MeetPR.surfaceElevated,
      dark: .init(22, 22, 24),
      light: .init(255, 255, 255)
    )
    try assertDynamicColor(
      .MeetPR.surfaceKey,
      dark: .init(28, 28, 32),
      light: .init(243, 244, 246)
    )
    try assertDynamicColor(
      .MeetPR.surfaceRaised,
      dark: .init(35, 35, 39),
      light: .init(238, 240, 243)
    )
    try assertDynamicColor(
      .MeetPR.videoStageFill,
      dark: .init(27, 37, 52),
      light: .init(27, 37, 52)
    )
    try assertDynamicColor(
      .MeetPR.videoStageBorder,
      dark: .init(42, 54, 70),
      light: .init(42, 54, 70)
    )
  }

  @Test("border tokens match both v3 themes")
  func borderTokensMatchBothThemes() throws {
    try assertDynamicColor(
      .MeetPR.borderHairline,
      dark: .init(23, 23, 26),
      light: .init(233, 235, 238)
    )
    try assertDynamicColor(
      .MeetPR.borderSubtle,
      dark: .init(30, 30, 34),
      light: .init(229, 231, 235)
    )
    try assertDynamicColor(
      .MeetPR.borderDefault,
      dark: .init(38, 38, 41),
      light: .init(229, 231, 235)
    )
    try assertDynamicColor(
      .MeetPR.borderStrong,
      dark: .init(46, 46, 50),
      light: .init(209, 213, 219)
    )
  }

  @Test("text tokens match both v3 themes")
  func textTokensMatchBothThemes() throws {
    try assertDynamicColor(
      .MeetPR.textPrimary,
      dark: .init(237, 237, 237),
      light: .init(17, 24, 39)
    )
    try assertDynamicColor(
      .MeetPR.textSecondary,
      dark: .init(200, 200, 204),
      light: .init(75, 85, 99)
    )
    try assertDynamicColor(
      .MeetPR.textTertiary,
      dark: .init(161, 161, 166),
      light: .init(92, 99, 113)
    )
    try assertDynamicColor(
      .MeetPR.textMuted,
      dark: .init(138, 138, 144),
      light: .init(92, 99, 113)
    )
    try assertDynamicColor(
      .MeetPR.textFaint,
      dark: .init(138, 138, 144),
      light: .init(92, 99, 113)
    )
    try assertDynamicColor(
      .MeetPR.textDim,
      dark: .init(138, 138, 144),
      light: .init(92, 99, 113)
    )
    try assertDynamicColor(
      .MeetPR.textDisabled,
      dark: .init(85, 85, 92),
      light: .init(156, 163, 175)
    )
    try assertDynamicColor(
      .MeetPR.textGhost,
      dark: .init(62, 62, 68),
      light: .init(209, 213, 219)
    )
  }

  @Test("gold tokens match both v3 themes")
  func goldTokensMatchBothThemes() throws {
    try assertDynamicColor(.MeetPR.goldCTA, dark: .init(255, 184, 0), light: .init(180, 83, 9))
    try assertDynamicColor(.MeetPR.gold500, dark: .init(245, 166, 35), light: .init(217, 119, 6))
    try assertDynamicColor(.MeetPR.gold400, dark: .init(251, 191, 62), light: .init(245, 158, 11))
    try assertDynamicColor(.MeetPR.gold200, dark: .init(255, 226, 142), light: .init(254, 243, 199))
    try assertDynamicColor(.MeetPR.goldRGB, dark: .init(245, 166, 35), light: .init(217, 119, 6))
    try assertDynamicColor(.MeetPR.goldText, dark: .init(245, 166, 35), light: .init(154, 74, 6))
    try assertDynamicColor(
      .MeetPR.inkOnGold,
      dark: .init(20, 20, 20),
      light: .init(255, 255, 255)
    )
    try assertDynamicColor(
      .MeetPR.goldGradientStart,
      dark: .init(224, 143, 15),
      light: .init(217, 119, 6)
    )
    try assertDynamicColor(
      .MeetPR.goldGradientEnd,
      dark: .init(255, 201, 60),
      light: .init(245, 185, 60)
    )
  }

  @Test("semantic tokens match both v3 themes")
  func semanticTokensMatchBothThemes() throws {
    try assertDynamicColor(.MeetPR.success, dark: .init(94, 158, 120), light: .init(21, 128, 61))
    try assertDynamicColor(
      .MeetPR.successSoft,
      dark: .init(159, 199, 174),
      light: .init(21, 128, 61)
    )
    try assertDynamicColor(
      .MeetPR.successRGB,
      dark: .init(94, 158, 120),
      light: .init(21, 128, 61)
    )
    try assertDynamicColor(.MeetPR.danger, dark: .init(229, 72, 77), light: .init(229, 72, 77))
    try assertDynamicColor(
      .MeetPR.dangerRGB,
      dark: .init(229, 72, 77),
      light: .init(229, 72, 77)
    )
    try assertDynamicColor(
      .MeetPR.dangerMuted,
      dark: .init(200, 136, 136),
      light: .init(163, 59, 64)
    )
    try assertDynamicColor(
      .MeetPR.dangerFill,
      dark: .init(192, 52, 58),
      light: .init(192, 52, 58)
    )
    try assertDynamicColor(
      .MeetPR.chartLine,
      dark: .init(220, 227, 234),
      light: .init(154, 164, 176)
    )
  }

  @Test("CTA and shadow tokens match both v3 themes")
  func ctaAndShadowTokensMatchBothThemes() throws {
    try assertDynamicColor(
      .MeetPR.ctaBackground,
      dark: .init(255, 184, 0),
      light: .init(17, 24, 39)
    )
    try assertDynamicColor(
      .MeetPR.ctaText,
      dark: .init(20, 20, 20),
      light: .init(255, 255, 255)
    )
    try assertDynamicColor(
      .MeetPR.ctaFill,
      dark: .init(17, 24, 39),
      light: .init(17, 24, 39)
    )
    try assertDynamicColor(
      .MeetPR.cardShadow,
      dark: .init(0, 0, 0, alpha: 0),
      light: .init(17, 24, 39, alpha: 0.06)
    )
  }

  @Test("mockup shell tokens match both v3 themes")
  func mockupShellTokensMatchBothThemes() throws {
    try assertDynamicColor(.MeetPR.bezel, dark: .init(28, 28, 30), light: .init(28, 28, 30))
    try assertDynamicColor(
      .MeetPR.bezelEdge,
      dark: .init(42, 42, 45),
      light: .init(42, 42, 45)
    )
    try assertDynamicColor(.MeetPR.desk1, dark: .init(26, 26, 30), light: .init(233, 233, 238))
    try assertDynamicColor(.MeetPR.desk2, dark: .init(5, 5, 6), light: .init(210, 210, 217))
  }
}

private func assertDynamicColor(
  _ color: Color,
  dark: ColorComponents,
  light: ColorComponents,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try assertColor(color, equals: dark, scheme: .dark, sourceLocation: sourceLocation)
  try assertColor(color, equals: light, scheme: .light, sourceLocation: sourceLocation)
}

private func assertColor(
  _ color: Color,
  equals expected: ColorComponents,
  scheme: ColorScheme = .dark,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let actual = try resolvedComponents(for: color, scheme: scheme)
  let tolerance = 1.0 / 255.0

  #expect(abs(actual.red - expected.red) <= tolerance, sourceLocation: sourceLocation)
  #expect(abs(actual.green - expected.green) <= tolerance, sourceLocation: sourceLocation)
  #expect(abs(actual.blue - expected.blue) <= tolerance, sourceLocation: sourceLocation)
  #expect(abs(actual.alpha - expected.alpha) <= tolerance, sourceLocation: sourceLocation)
}

private func resolvedComponents(for color: Color, scheme: ColorScheme) throws -> ColorComponents {
  #if canImport(UIKit)
    let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
    let resolved = UIColor(color).resolvedColor(with: traits)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return ColorComponents(red, green, blue, alpha: alpha)
  #elseif canImport(AppKit)
    let appearanceName: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
    guard let appearance = NSAppearance(named: appearanceName) else {
      throw ColorTestError.unresolvedColor
    }

    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
      resolved = NSColor(color).usingColorSpace(.deviceRGB)
    }
    guard let rgb = resolved else {
      throw ColorTestError.unresolvedColor
    }

    return ColorComponents(
      rgb.redComponent,
      rgb.greenComponent,
      rgb.blueComponent,
      alpha: rgb.alphaComponent
    )
  #else
    throw ColorTestError.unsupportedPlatform
  #endif
}
