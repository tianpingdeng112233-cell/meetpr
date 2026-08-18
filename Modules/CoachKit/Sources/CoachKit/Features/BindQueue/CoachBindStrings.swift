import Foundation

enum CoachBindStrings {
  static func waitingMinutes(_ count: Int, locale: Locale = .current) -> String {
    CoachLocalization.localized("coach.bind.waiting.minutes \(count)", locale: locale)
  }

  static func waitingHours(_ count: Int, locale: Locale = .current) -> String {
    CoachLocalization.localized("coach.bind.waiting.hours \(count)", locale: locale)
  }

  static func waitingHoursMinutes(
    _ hours: Int,
    _ minutes: Int,
    locale: Locale = .current
  ) -> String {
    CoachLocalization.localized(
      "coach.bind.waiting.hoursMinutes \(hours) \(minutes)", locale: locale)
  }

  static func waitingDays(
    _ count: Int,
    locale: Locale = .current,
    bundle: Bundle = .module
  ) -> String {
    CoachLocalization.localized(
      "coach.bind.waiting.days \(count)", locale: locale, bundle: bundle)
  }

  static func trainingYears(_ count: Int, locale: Locale = .current) -> String {
    CoachLocalization.localized("coach.bind.training.years \(count)", locale: locale)
  }

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
