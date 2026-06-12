import Foundation

enum PlanningDecimalStep {
  static let half = Decimal(5) / Decimal(10)
  static let whole = Decimal(1)
  /// Plate-realistic grid for %-of-base results (smallest pair = 1.25kg×2).
  static let plate = Decimal(25) / Decimal(10)
}

extension Decimal {
  var planningDoubleValue: Double {
    Double(truncating: self as NSDecimalNumber)
  }

  func planningFormatted(maxFractionDigits: Int = 1) -> String {
    formatted(.number.precision(.fractionLength(0...maxFractionDigits)))
  }

  func roundedToPlanningIncrement(_ increment: Decimal) -> Decimal {
    guard increment > 0 else { return self }

    var quotient = self / increment
    var roundedQuotient = Decimal()
    NSDecimalRound(&roundedQuotient, &quotient, 0, .plain)
    return roundedQuotient * increment
  }

  static func planningRounded(_ value: Double, increment: Decimal) -> Decimal {
    guard value.isFinite else { return 0 }
    return Decimal(value).roundedToPlanningIncrement(increment)
  }
}
