import Foundation

enum AnalyticsStrings {
  static let frictionTitle = localized("analytics.friction.title")
  static let frictionPlaceholder = localized("analytics.friction.placeholder")
  static let skip = localized("analytics.friction.skip")
  static let send = localized("analytics.friction.send")

  private static func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
  }
}
