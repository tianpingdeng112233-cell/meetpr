import SwiftUI

#if canImport(AppKit)
  import AppKit
#endif

#if canImport(UIKit)
  import UIKit
#endif

enum MeetPRFontFamily {
  enum Source: Equatable, Sendable {
    case custom(String)
    case system
  }

  static let archivoExtraBold = "ArchivoRoman-ExtraBold"
  static let archivoBlack = "ArchivoRoman-Black"

  static let ibmPlexMonoRegular = "IBMPlexMono-Regular"
  static let ibmPlexMonoMedium = "IBMPlexMono-Medium"
  static let ibmPlexMonoSemibold = "IBMPlexMono-SemiBold"
  static let ibmPlexMonoBold = "IBMPlexMono-Bold"

  static let ibmPlexSansRegular = "IBMPlexSans-Regular"
  static let ibmPlexSansMedium = "IBMPlexSans-Medium"
  static let ibmPlexSansSemibold = "IBMPlexSans-SemiBold"
  static let ibmPlexSansBold = "IBMPlexSans-Bold"

  static func font(
    named name: String,
    size: CGFloat,
    fallbackWeight: Font.Weight,
    design: Font.Design = .default
  ) -> Font {
    switch source(named: name) {
    case .system:
      return .system(size: size, weight: fallbackWeight, design: design)
    case .custom(let postScriptName):
      return .custom(postScriptName, size: size)
    }
  }

  static func source(
    named name: String,
    availability: (String) -> Bool = isAvailable
  ) -> Source {
    availability(name) ? .custom(name) : .system
  }

  static func isAvailable(_ name: String) -> Bool {
    #if canImport(UIKit)
      UIFont(name: name, size: 12) != nil
    #elseif canImport(AppKit)
      NSFont(name: name, size: 12) != nil
    #else
      false
    #endif
  }
}
