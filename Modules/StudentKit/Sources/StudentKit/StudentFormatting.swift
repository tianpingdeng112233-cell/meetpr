import CoreModels
import Foundation

struct PercentagePrescriptionPresentation: Equatable, Sendable {
  let weightPrimary: String
  let weightUnit: String?
  let weightSecondary: String?
  let isMuted: Bool
}

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

  static func prescribed(
    _ set: PrescribedSet,
    percentageOutcome: SetWeightSuggestionOutcome? = nil
  ) -> String {
    // Legacy rows (load_mode == null) keep the pre-072 string byte-for-byte;
    // only new-form rows get the six-form rendering (spec 072 §1.4).
    if set.isLegacyPrescription {
      let reps: String
      if let lowerBound = set.reps, let upperBound = set.repsMax {
        reps = "\(lowerBound)-\(upperBound)"
      } else {
        reps = set.reps.map(String.init) ?? "-"
      }
      return "\(decimal(set.weightKg))kg x \(reps)"
    }

    let reps: String
    if let lowerBound = set.reps, let upperBound = set.repsMax {
      reps = "\(lowerBound)–\(upperBound)"
    } else {
      reps = set.reps.map(String.init) ?? "-"
    }
    if case .weightRange(let low, let high) = set.intensity {
      return "\(weightDecimal(low))–\(weightDecimal(high))kg × \(reps)"
    }

    if case .percentage(let value) = set.intensity,
      let percentageOutcome
    {
      return "\(percentagePrescription(value, set: set, outcome: percentageOutcome)) × \(reps)"
    }

    if let weightKg = set.weightKg {
      var result = "\(weightDecimal(weightKg))kg × \(reps)"
      if let intensity = set.intensity {
        result += " @\(inlineIntensity(intensity))"
      }
      return result
    }

    if let intensity = set.intensity {
      return "\(intensityText(intensity)) × \(reps)"
    }
    return "× \(reps)"
  }

  static func intensityText(_ intensity: PrescribedIntensity) -> String {
    switch intensity {
    case .percentage(let value):
      "\(decimal(value))%"
    case .rpe(let value):
      "RPE \(decimal(value))"
    case .rir(let value):
      "RIR \(value)"
    case .rpeRange(let low, let high):
      "RPE \(decimal(low))–\(decimal(high))"
    case .weightRange(let low, let high):
      "\(weightDecimal(low))–\(weightDecimal(high))kg"
    }
  }

  static func percentageAnchorText(
    _ set: PrescribedSet,
    source: PctAnchorResolutionSource? = nil
  ) -> String? {
    guard case .percentage(let value) = set.intensity else { return nil }
    let percentage = decimal(value)
    if let source {
      switch source {
      case .registeredOneRM, .fallbackToRegisteredOneRM:
        return StudentStrings.replacing(.todayWorkoutTypes014, values: [percentage])
      case .e1RM:
        return StudentStrings.replacing(.todayWorkoutTypes015, values: [percentage])
      case .topSet:
        return StudentStrings.replacing(.todayWorkoutTypes016, values: [percentage])
      case .unresolved:
        break
      }
    }
    switch set.effectivePercentageAnchor {
    case .registeredOneRM:
      return StudentStrings.replacing(.todayWorkoutTypes014, values: [percentage])
    case .e1RM:
      return StudentStrings.replacing(.todayWorkoutTypes015, values: [percentage])
    case .topSet:
      return StudentStrings.replacing(.todayWorkoutTypes016, values: [percentage])
    }
  }

  static func percentagePresentation(
    set: PrescribedSet,
    actualWeight: Decimal?,
    outcome: SetWeightSuggestionOutcome
  ) -> PercentagePrescriptionPresentation? {
    guard case .percentage(let value) = set.intensity else { return nil }
    let raw = "\(decimal(value))%"

    if let actualWeight {
      return PercentagePrescriptionPresentation(
        weightPrimary: weightDecimal(actualWeight),
        weightUnit: "kg",
        weightSecondary: percentageAnchorText(set, source: outcome.percentageSource),
        isMuted: false
      )
    }

    if let suggestion = outcome.suggestion,
      case .percentage(let source) = suggestion.basis
    {
      return PercentagePrescriptionPresentation(
        weightPrimary: StudentStrings.replacing(
          .todayWorkoutTypes019,
          values: [weightDecimal(suggestion.weightKg)]
        ),
        weightUnit: "kg",
        weightSecondary: percentageAnchorText(set, source: source),
        isMuted: false
      )
    }

    if outcome.unavailableReason == .topSetNotCompleted {
      return PercentagePrescriptionPresentation(
        weightPrimary: "\(raw) × \(StudentStrings.localized(.todayWorkoutTypes029))",
        weightUnit: nil,
        weightSecondary: StudentStrings.localized(.todayWorkoutTypes026),
        isMuted: true
      )
    }

    return PercentagePrescriptionPresentation(
      weightPrimary: raw,
      weightUnit: nil,
      weightSecondary: nil,
      isMuted: true
    )
  }

  static func percentagePrescription(
    _ value: Decimal,
    set: PrescribedSet,
    outcome: SetWeightSuggestionOutcome
  ) -> String {
    let raw = "\(decimal(value))%"
    if let suggestion = outcome.suggestion,
      case .percentage(let source) = suggestion.basis,
      let anchorText = percentageAnchorText(set, source: source)
    {
      return StudentStrings.replacing(
        .todayWorkoutTypes017,
        values: [weightDecimal(suggestion.weightKg), anchorText]
      )
    }
    switch outcome.unavailableReason {
    case .topSetNotCompleted:
      guard let anchorText = percentageAnchorText(set) else { return raw }
      return StudentStrings.replacing(.todayWorkoutTypes018, values: [anchorText])
    case .missingRegisteredOneRM:
      return percentageAnchorText(set) ?? raw
    case .unsupportedPercentageExercise:
      return raw
    default:
      return raw
    }
  }

  private static func inlineIntensity(_ intensity: PrescribedIntensity) -> String {
    switch intensity {
    case .percentage(let value):
      "\(decimal(value))%"
    case .rpe(let value):
      "RPE\(decimal(value))"
    case .rir(let value):
      "RIR\(value)"
    case .rpeRange(let low, let high):
      "RPE\(decimal(low))–\(decimal(high))"
    case .weightRange(let low, let high):
      "\(weightDecimal(low))–\(weightDecimal(high))kg"
    }
  }

  private static func weightDecimal(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).doubleValue.formatted(
      .number.precision(.fractionLength(0...2))
    )
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
