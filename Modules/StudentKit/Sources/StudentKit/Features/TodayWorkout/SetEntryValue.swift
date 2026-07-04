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
    min(10, max(5, decimal(text)))
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
