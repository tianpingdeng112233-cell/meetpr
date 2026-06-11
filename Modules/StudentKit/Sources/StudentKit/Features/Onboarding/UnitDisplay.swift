import CoreModels
import Foundation

/// kg↔lb / cm↔in display lens (spec 032 D1): the wire and the draft stay
/// metric; conversions live only in this formatter/parser layer. Switching
/// units never rewrites stored values, only their rendering.
public enum UnitDisplay {
  /// Exact avoirdupois factor.
  public static let lbPerKg = Decimal(string: "2.2046226218")!
  public static let inchPerCm = Decimal(string: "0.3937007874")!

  // MARK: - Display (metric → preferred unit string)

  public static func weightText(kg kilograms: Decimal?, unit: UnitPreference) -> String {
    guard let kilograms else { return "" }
    switch unit {
    case .kg: return plainString(kilograms)
    case .lb: return plainString(rounded(kilograms * lbPerKg, scale: 1))
    }
  }

  public static func heightText(cm centimeters: Decimal?, unit: UnitPreference) -> String {
    guard let centimeters else { return "" }
    switch unit {
    case .kg: return plainString(centimeters)
    case .lb: return plainString(rounded(centimeters * inchPerCm, scale: 1))
    }
  }

  public static func weightUnitSuffix(_ unit: UnitPreference) -> String {
    unit == .kg ? "kg" : "lb"
  }

  public static func heightUnitSuffix(_ unit: UnitPreference) -> String {
    unit == .kg ? "cm" : "in"
  }

  // MARK: - Parse (typed text in preferred unit → metric Decimal)

  /// Returns kg rounded to 2 decimals (wire scale); nil for non-numeric.
  public static func parseWeight(_ text: String, unit: UnitPreference) -> Decimal? {
    guard let value = parseDecimal(text) else { return nil }
    let kilograms: Decimal
    switch unit {
    case .kg: kilograms = rounded(value, scale: 2)
    case .lb: kilograms = rounded(value / lbPerKg, scale: 2)
    }
    // Backend zod bounds (0, 500) exclusive — never produce an illegal wire
    // value; nil keeps the step gated (Codex P1).
    guard kilograms > 0, kilograms < 500 else { return nil }
    return kilograms
  }

  /// Returns cm rounded to 1 decimal (wire scale); nil for non-numeric.
  public static func parseHeight(_ text: String, unit: UnitPreference) -> Decimal? {
    guard let value = parseDecimal(text) else { return nil }
    let centimeters: Decimal
    switch unit {
    case .kg: centimeters = rounded(value, scale: 1)
    case .lb: centimeters = rounded(value / inchPerCm, scale: 1)
    }
    // Backend zod bounds (0, 300) exclusive (Codex P1).
    guard centimeters > 0, centimeters < 300 else { return nil }
    return centimeters
  }

  /// 1RM entry is always kg (0.5 grid handled by the estimator; manual input
  /// rounds to 2 decimals).
  public static func parseOneRM(_ text: String) -> Decimal? {
    guard let value = parseDecimal(text), value > 0, value < 1000 else { return nil }
    return rounded(value, scale: 2)
  }

  // MARK: - Helpers

  public static func rounded(_ value: Decimal, scale: Int) -> Decimal {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, scale, .plain)
    return output
  }

  public static func plainString(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private static func parseDecimal(_ text: String) -> Decimal? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
      .trimmingCharacters(in: .whitespaces)
    guard !normalized.isEmpty else { return nil }
    return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
  }
}
