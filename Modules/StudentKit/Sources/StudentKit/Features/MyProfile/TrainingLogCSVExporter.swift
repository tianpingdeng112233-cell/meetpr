import CoreModels
import Foundation

/// Converts the student's complete set ledger to an RFC 4180-compatible CSV.
public enum TrainingLogCSVExporter {
  public static let header =
    "date,exercise,exercise_en,set_index,weight_kg,reps,rpe,completed,failed,adhoc"

  /// Names are keyed by plan-exercise identity on the release/1.0 data model.
  public static func csv(
    logs: [StudentSetLog],
    names: [UUID: (name: String, nameEn: String?)],
    calendar: Calendar = .current
  ) -> String {
    let rows = logs.sorted { $0.loggedAt < $1.loggedAt }.map { log in
      let resolved = names[log.planExerciseID]
      let fields = [
        dayString(log.loggedAt, calendar: calendar),
        resolved?.name ?? log.planExerciseID.uuidString,
        resolved?.nameEn ?? "",
        String(log.setIndex),
        "\(log.weightKg)",
        String(log.reps),
        log.rpe.map { "\($0)" } ?? "",
        log.completed ? "true" : "false",
        log.failed ? "true" : "false",
        "false",
      ]
      return fields.map(escape).joined(separator: ",")
    }
    return ([header] + rows).joined(separator: "\n")
  }

  static func dayString(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return [
      padded(parts.year ?? 0, digits: 4),
      padded(parts.month ?? 0, digits: 2),
      padded(parts.day ?? 0, digits: 2),
    ].joined(separator: "-")
  }

  static func compactDayString(_ date: Date, calendar: Calendar) -> String {
    dayString(date, calendar: calendar).replacing("-", with: "")
  }

  static func escape(_ field: String) -> String {
    guard
      field.contains(",") || field.contains("\"") || field.contains("\n")
        || field.contains("\r")
    else {
      return field
    }
    return "\"\(field.replacing("\"", with: "\"\""))\""
  }

  private static func padded(_ value: Int, digits: Int) -> String {
    value.formatted(
      .number
        .grouping(.never)
        .precision(.integerLength(digits))
    )
  }
}
