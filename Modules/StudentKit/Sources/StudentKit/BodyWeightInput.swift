import CoreModels
import Foundation

/// The body-weight lens preserves metric storage while accepting the local decimal separator.
enum BodyWeightInput {
  static func filtered(_ input: String, locale: Locale = .current) -> String {
    let separator = locale.decimalSeparator ?? "."
    var result = ""
    var hasSeparator = false
    var fractionCount = 0
    for character in input {
      if String(character) == separator || character == "." {
        if !hasSeparator {
          result += separator
          hasSeparator = true
        }
      } else if character >= "0", character <= "9" {
        guard !hasSeparator || fractionCount < 2 else { continue }
        result.append(character)
        if hasSeparator { fractionCount += 1 }
      }
    }
    return result
  }

  static func kilograms(
    _ input: String, unit: UnitPreference, locale: Locale = .current
  ) -> Decimal? {
    guard !input.isEmpty, filtered(input, locale: locale) == input else { return nil }
    let normalized = input.replacing(locale.decimalSeparator ?? ".", with: ".")
    return UnitDisplay.parseWeight(normalized, unit: unit)
  }

  static func text(
    kg kilograms: Decimal?, unit: UnitPreference, locale: Locale = .current
  ) -> String {
    guard let kilograms else { return "" }
    let value = unit == .kg ? kilograms : kilograms * UnitDisplay.lbPerKg
    return value.formatted(
      .number.locale(locale).precision(.fractionLength(2)).grouping(.never))
  }
}
