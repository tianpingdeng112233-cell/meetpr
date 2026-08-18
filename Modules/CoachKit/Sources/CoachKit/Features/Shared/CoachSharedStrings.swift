import Foundation

enum CoachSharedStrings {
  static func active(locale: Locale = .current) -> String {
    localized("coach.shared.status.active", locale: locale)
  }

  static func noMuscleFatigue(locale: Locale = .current) -> String {
    localized("coach.shared.readiness.noMuscleFatigue", locale: locale)
  }

  static func evaluationDays(_ days: Int, locale: Locale = .current) -> String {
    days == 1
      ? CoachLocalization.localized("coach.shared.status.evaluationDay \(days)", locale: locale)
      : CoachLocalization.localized("coach.shared.status.evaluationDays \(days)", locale: locale)
  }

  static func evaluationHours(_ hours: Int, locale: Locale = .current) -> String {
    hours == 1
      ? CoachLocalization.localized("coach.shared.status.evaluationHour \(hours)", locale: locale)
      : CoachLocalization.localized("coach.shared.status.evaluationHours \(hours)", locale: locale)
  }

  static func daysNotTrained(_ days: Int, locale: Locale = .current) -> String {
    days == 1
      ? CoachLocalization.localized("coach.shared.abnormal.dayNotTrained \(days)", locale: locale)
      : CoachLocalization.localized("coach.shared.abnormal.daysNotTrained \(days)", locale: locale)
  }

  static func stuckOnWeek(_ week: Int, locale: Locale = .current) -> String {
    CoachLocalization.localized("coach.shared.abnormal.stuckOnWeek \(week)", locale: locale)
  }

  static func minutesAgo(_ minutes: Int, locale: Locale = .current) -> String {
    minutes == 1
      ? CoachLocalization.localized("coach.shared.relative.minuteAgo \(minutes)", locale: locale)
      : CoachLocalization.localized("coach.shared.relative.minutesAgo \(minutes)", locale: locale)
  }

  static func hoursAgo(_ hours: Int, locale: Locale = .current) -> String {
    hours == 1
      ? CoachLocalization.localized("coach.shared.relative.hourAgo \(hours)", locale: locale)
      : CoachLocalization.localized("coach.shared.relative.hoursAgo \(hours)", locale: locale)
  }

  static func daysAgo(_ days: Int, locale: Locale = .current) -> String {
    days == 1
      ? CoachLocalization.localized("coach.shared.relative.dayAgo \(days)", locale: locale)
      : CoachLocalization.localized("coach.shared.relative.daysAgo \(days)", locale: locale)
  }

  static func readinessScales(
    sleep: Int,
    mood: Int,
    stress: Int,
    locale: Locale = .current
  ) -> String {
    CoachLocalization.localized(
      "coach.shared.readiness.scales \(sleep) \(mood) \(stress)", locale: locale)
  }

  static func fatigue(_ items: String, locale: Locale = .current) -> String {
    replacing("coach.shared.readiness.fatigue", values: ["items": items], locale: locale)
  }

  static func muscleGroup(_ key: String.LocalizationValue, locale: Locale = .current) -> String {
    localized(key, locale: locale)
  }

  static func severity(_ severity: Int, locale: Locale = .current) -> String {
    let key: String.LocalizationValue =
      switch severity {
      case 1: "coach.shared.severity.light"
      case 2: "coach.shared.severity.moderate"
      default: "coach.shared.severity.heavy"
      }
    return localized(key, locale: locale)
  }

  private static func localized(
    _ key: String.LocalizationValue,
    locale: Locale
  ) -> String {
    CoachLocalization.localized(key, locale: locale)
  }

  private static func replacing(
    _ key: String.LocalizationValue,
    values: [String: String],
    locale: Locale
  ) -> String {
    CoachLocalization.replacing(key, values: values, locale: locale)
  }
}
