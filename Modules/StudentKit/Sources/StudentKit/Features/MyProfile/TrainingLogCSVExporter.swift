import CoreModels
import Foundation

/// 「永不锁数据」落地物 (spec 048 §4): the student's complete set log as a
/// plain CSV. Pure functions — the share/UI layer owns file handling.
public enum TrainingLogCSVExporter {
  public static let header =
    "date,exercise,exercise_en,set_index,weight_kg,reps,rpe,completed,failed,adhoc"

  /// English + Chinese name pair per exercise id; unresolvable ids fall back
  /// to the raw UUID so no row is ever dropped.
  public static func csv(
    logs: [StudentSetLog],
    names: [UUID: (name: String, nameEn: String?)],
    calendar: Calendar = .current
  ) -> String {
    let rows =
      logs
      .sorted { $0.loggedAt < $1.loggedAt }
      .map { log -> String in
        let resolved = log.exerciseID.flatMap { names[$0] }
        let fallback = log.exerciseID?.uuidString ?? log.planExerciseID?.uuidString ?? ""
        let fields = [
          dayString(log.loggedAt, calendar: calendar),
          resolved?.name ?? fallback,
          resolved?.nameEn ?? "",
          String(log.setIndex),
          "\(log.weightKg)",
          String(log.reps),
          log.rpe.map { "\($0)" } ?? "",
          log.completed ? "true" : "false",
          log.failed ? "true" : "false",
          log.adhoc ? "true" : "false",
        ]
        return fields.map(escape).joined(separator: ",")
      }
    // Empty data still exports the header — honest, not a fake failure.
    return ([header] + rows).joined(separator: "\n")
  }

  /// Local-calendar YYYY-MM-DD. Nonisolated twin of the session-side helper
  /// (that one is MainActor-bound; this exporter stays pure).
  static func dayString(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  /// RFC 4180: quote fields containing commas, quotes, or newlines;
  /// double the embedded quotes.
  static func escape(_ field: String) -> String {
    guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
      return field
    }
    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
