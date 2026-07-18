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
    public static let brandRed = rgb(229, 34, 30)
    public static let brandRedPress = rgb(184, 26, 23)
    public static let brandRedSoft = Color(
      light: rgb(229, 34, 30, opacity: 0.08),
      dark: rgb(229, 34, 30, opacity: 0.12)
    )

    public static let green = rgb(31, 179, 88)
    public static let greenSoft = rgb(31, 179, 88, opacity: 0.14)
    public static let signalYellow = rgb(245, 197, 24)
    public static let amber = rgb(224, 168, 16)
    public static let amberSoft = rgb(224, 168, 16, opacity: 0.14)

    // swiftlint:disable:next identifier_name
    public static let bg = Color(light: rgb(250, 250, 250), dark: rgb(0, 0, 0))
    public static let surface1 = Color(light: rgb(255, 255, 255), dark: rgb(14, 14, 14))
    public static let surface2 = Color(light: rgb(244, 244, 245), dark: rgb(22, 22, 22))
    public static let surface3 = Color(light: rgb(233, 233, 235), dark: rgb(31, 31, 31))
    public static let border = Color(light: rgb(229, 229, 229), dark: rgb(38, 38, 38))
    public static let borderStrong = Color(light: rgb(201, 201, 201), dark: rgb(58, 58, 58))
    public static let fgPrimary = Color(light: rgb(10, 10, 10), dark: rgb(255, 255, 255))
    public static let fgSecondary = Color(light: rgb(82, 82, 82), dark: rgb(181, 181, 181))
    public static let fgTertiary = Color(light: rgb(163, 163, 163), dark: rgb(115, 115, 115))
    public static let fgDisabled = Color(
      light: rgb(10, 10, 10, opacity: 0.35),
      dark: rgb(255, 255, 255, opacity: 0.35)
    )

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
