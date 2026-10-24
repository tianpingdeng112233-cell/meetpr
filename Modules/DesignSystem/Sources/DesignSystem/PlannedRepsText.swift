import Foundation

/// Planned repetitions only. Performed repetitions keep their numeric value.
public enum PlannedRepsText {
  public static func text(
    reps: Int?, repsMax: Int? = nil, toFailure: Bool,
    rangeSeparator: String = "–", locale: Locale = .current
  ) -> String {
    if toFailure {
      return locale.language.languageCode?.identifier == "zh" ? "力竭" : "to failure"
    }
    if let reps, let repsMax { return "\(reps)\(rangeSeparator)\(repsMax)" }
    return reps.map(String.init) ?? "-"
  }
}
