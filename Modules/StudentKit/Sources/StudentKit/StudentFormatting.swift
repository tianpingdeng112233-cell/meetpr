import CoreModels
import Foundation

enum StudentFormatting {
  static let dayMonthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter
  }()

  static let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "EEEE"
    return formatter
  }()

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
