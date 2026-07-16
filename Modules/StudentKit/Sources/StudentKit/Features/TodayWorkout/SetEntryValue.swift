import Foundation

/// Parsing + range-clamping for the set-entry number fields. Kept as free
/// functions rather than inline in the view so the "type a value then commit"
/// path is unit-testable and the clamps live in one place. The fields bind to
/// String state (not `TextField(value:format:)`), so the committed value is
/// always the current text — no focus-loss parse race when the footer button
/// reads the value in the same action.
enum SetEntryValue {
  static func weight(from text: String) -> Decimal {
    max(0, decimal(text))
  }

  static func reps(from text: String) -> Int {
    max(0, Int(text.trimmingCharacters(in: .whitespaces)) ?? 0)
  }

  static func rpe(from text: String) -> Decimal {
    snapRPE(decimal(text))
  }

  /// Clamp to 5…10 and snap to the nearest 0.5 — RPE is half-point-grained, so
  /// the value the scale shows and the value we save stay on a tick even when a
  /// prescribed/legacy value (e.g. 8.2) isn't already aligned.
  static func snapRPE(_ value: Decimal) -> Decimal {
    var source = value * 2
    var rounded = Decimal()
    NSDecimalRound(&rounded, &source, 0, .plain)
    return min(10, max(5, rounded / 2))
  }

  /// Canonical text for an RPE `Double` coming off the tick scale: snap to the
  /// half-step lattice with exact integer math (no `String(format:)` round-trip)
  /// so 8.5 stays 8.5 and out-of-range values clamp.
  static func rpeText(_ value: Double) -> String {
    let halfSteps = Int((value * 2).rounded())
    return text(min(10, max(5, Decimal(halfSteps) / 2)))
  }

  static func text(_ value: Decimal) -> String {
    StudentFormatting.decimal(value)
  }

  private static func decimal(_ text: String) -> Decimal {
    // Normalize comma decimals and pin the separator to POSIX, matching
    // UnitDisplay.parseDecimal — otherwise a `.decimalPad` comma in some locales
    // parses "172,5" as 172 and silently saves the wrong load.
    let normalized = text.replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) ?? 0
  }
}
