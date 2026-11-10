import SwiftUI

/// A localized placeholder is display-only; shortcuts preserve the original number.
@MainActor
struct MeetPRNumberPadInputValue {
  let placeholder: String
  private let initialValue: Double
  private let field: MeetPRNumberPad.Field
  private let minimumWeight: Double

  init(
    value: Double,
    field: MeetPRNumberPad.Field,
    minimumWeight: Double = 20,
    locale: Locale = .current
  ) {
    self.initialValue = value
    self.field = field
    self.minimumWeight = minimumWeight
    self.placeholder =
      field == .reps
      ? value.rounded().formatted(.number.precision(.fractionLength(0)).locale(locale))
      : value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
  }

  func resolve(_ text: String) -> Double {
    let rawValue = Double(text) ?? initialValue
    return MeetPRNumberPad.snapped(rawValue, field: field, minimumWeight: minimumWeight)
  }
}
