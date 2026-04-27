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

  init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
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

@Suite("MeetPR color tokens")
struct ColorsTests {
  @Test("brand colors match CSS root")
  func brandColorsMatchCSSRoot() throws {
    try assertColor(Color.MeetPR.brandRed, equals: .init(red: 229, green: 34, blue: 30))
    try assertColor(Color.MeetPR.brandRedPress, equals: .init(red: 184, green: 26, blue: 23))
    try assertColor(
      Color.MeetPR.brandRedSoft,
      equals: .init(red: 229, green: 34, blue: 30, alpha: 0.12),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.brandRedSoft,
      equals: .init(red: 229, green: 34, blue: 30, alpha: 0.08),
      scheme: .light
    )
  }

  @Test("semantic colors match CSS root")
  func semanticColorsMatchCSSRoot() throws {
    try assertColor(Color.MeetPR.green, equals: .init(red: 31, green: 179, blue: 88))
    try assertColor(
      Color.MeetPR.greenSoft,
      equals: .init(red: 31, green: 179, blue: 88, alpha: 0.14)
    )
    try assertColor(Color.MeetPR.amber, equals: .init(red: 224, green: 168, blue: 16))
    try assertColor(
      Color.MeetPR.amberSoft,
      equals: .init(red: 224, green: 168, blue: 16, alpha: 0.14)
    )
  }

  @Test("dark dynamic colors match CSS root")
  func darkDynamicColorsMatchCSSRoot() throws {
    try assertColor(Color.MeetPR.bg, equals: .init(red: 0, green: 0, blue: 0), scheme: .dark)
    try assertColor(
      Color.MeetPR.surface1,
      equals: .init(red: 14, green: 14, blue: 14),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.surface2,
      equals: .init(red: 22, green: 22, blue: 22),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.surface3,
      equals: .init(red: 31, green: 31, blue: 31),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.border,
      equals: .init(red: 38, green: 38, blue: 38),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.borderStrong,
      equals: .init(red: 58, green: 58, blue: 58),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.fgPrimary,
      equals: .init(red: 255, green: 255, blue: 255),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.fgSecondary,
      equals: .init(red: 181, green: 181, blue: 181),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.fgTertiary,
      equals: .init(red: 115, green: 115, blue: 115),
      scheme: .dark
    )
    try assertColor(
      Color.MeetPR.fgDisabled,
      equals: .init(red: 255, green: 255, blue: 255, alpha: 0.35),
      scheme: .dark
    )
  }

  @Test("light dynamic colors match CSS light override")
  func lightDynamicColorsMatchCSSLightOverride() throws {
    try assertColor(
      Color.MeetPR.bg,
      equals: .init(red: 250, green: 250, blue: 250),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.surface1,
      equals: .init(red: 255, green: 255, blue: 255),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.surface2,
      equals: .init(red: 244, green: 244, blue: 245),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.surface3,
      equals: .init(red: 233, green: 233, blue: 235),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.border,
      equals: .init(red: 229, green: 229, blue: 229),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.borderStrong,
      equals: .init(red: 201, green: 201, blue: 201),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.fgPrimary,
      equals: .init(red: 10, green: 10, blue: 10),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.fgSecondary,
      equals: .init(red: 82, green: 82, blue: 82),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.fgTertiary,
      equals: .init(red: 163, green: 163, blue: 163),
      scheme: .light
    )
    try assertColor(
      Color.MeetPR.fgDisabled,
      equals: .init(red: 10, green: 10, blue: 10, alpha: 0.35),
      scheme: .light
    )
  }
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
    return ColorComponents(red: red, green: green, blue: blue, alpha: alpha)
  #elseif canImport(AppKit)
    let appearanceName: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
    guard let appearance = NSAppearance(named: appearanceName) else {
      throw ColorTestError.unresolvedColor
    }

    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
      resolved = NSColor(color).usingColorSpace(NSColorSpace.deviceRGB)
    }
    guard let rgb = resolved else {
      throw ColorTestError.unresolvedColor
    }

    return ColorComponents(
      red: rgb.redComponent,
      green: rgb.greenComponent,
      blue: rgb.blueComponent,
      alpha: rgb.alphaComponent
    )
  #else
    throw ColorTestError.unsupportedPlatform
  #endif
}
