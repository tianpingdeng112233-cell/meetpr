import CoreModels
import Foundation

enum StudentFormatting {
  static func dayMonth(
    _ date: Date,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    var style = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
    style.timeZone = timeZone
    return date.formatted(style)
  }

  static func weekday(
    _ date: Date,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    var style = Date.FormatStyle.dateTime.weekday(.wide).locale(locale)
    style.timeZone = timeZone
    return date.formatted(style)
  }

  static func time(
    _ date: Date,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    var style = Date.FormatStyle.dateTime.hour().minute().locale(locale)
    style.timeZone = timeZone
    return date.formatted(style)
  }

  static func monthDay(
    _ date: Date,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    dayMonth(date, locale: locale, timeZone: timeZone)
  }

  static func numericMonthDay(
    _ date: Date,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    var style = Date.FormatStyle.dateTime
      .month(.defaultDigits)
      .day(.defaultDigits)
      .locale(locale)
    style.timeZone = timeZone
    return date.formatted(style)
  }

  /// Double weights (e1RM math output) formatted like `decimal(_:)`.
  static func kilograms(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  static func decimal(_ value: Decimal?) -> String {
    guard let value else {
      return "-"
    }
    return NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...1))
    )
  }

  static func prescribed(_ set: PrescribedSet) -> String {
    let reps: String
    if let lowerBound = set.reps, let upperBound = set.repsMax {
      reps = "\(lowerBound)-\(upperBound)"
    } else {
      reps = set.reps.map(String.init) ?? "-"
    }
    return "\(decimal(set.weightKg))kg x \(reps)"
  }

  /// A logged/achieved set line, e.g. "142.5kg × 5 @ RPE 7.5". Weight and RPE are
  /// dropped when absent (RPE-only or bodyweight work).
  static func result(weightKg: Decimal?, reps: Int, rpe: Decimal?) -> String {
    var line = ""
    if let weightKg {
      line += "\(decimal(weightKg))kg × "
    }
    line += "\(reps)"
    if let rpe {
      line += " @ RPE \(decimal(rpe))"
    }
    return line
  }

  static func completedCount(
    for day: StudentPlanDay,
    logs: [StudentSetLog]
  ) -> (completed: Int, total: Int) {
    let total = day.exercises.reduce(0) { $0 + $1.prescribedSets.count }
    let planExerciseIDs = Set(day.exercises.map(\.id))
    let completed = logs.filter {
      planExerciseIDs.contains($0.planExerciseID) && $0.completed && !$0.assumed
    }.count
    return (completed, total)
  }
}
