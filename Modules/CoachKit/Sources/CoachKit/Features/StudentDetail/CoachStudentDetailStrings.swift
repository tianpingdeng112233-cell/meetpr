import Foundation

enum CoachStudentDetailStrings {
  static func text(_ key: String.LocalizationValue, locale: Locale = .current) -> String {
    CoachLocalization.localized(key, locale: locale)
  }

  static func replacing(
    _ key: String.LocalizationValue,
    _ replacements: [String: CustomStringConvertible],
    locale: Locale = .current
  ) -> String {
    CoachLocalization.replacing(
      key,
      values: replacements.mapValues { String(describing: $0) },
      locale: locale)
  }
}
