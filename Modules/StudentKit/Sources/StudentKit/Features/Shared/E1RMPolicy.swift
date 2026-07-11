import Foundation

/// Tunable e1RM aggregation and PR policy parameters (spec 050 §§1–3).
/// Keep these values centralized so a future algorithm engine can replace
/// them without hunting through recording and presentation code.
enum E1RMPolicy {
  static let minimumEligibleRPE = 7.0
  static let maximumEligibleReps = 10
  static let maximumEligibleDeadliftReps = 5

  static let rollingWindowDays = 28
  static let rollingWindow = TimeInterval(rollingWindowDays * 24 * 60 * 60)

  static let minimumPRImprovementKg = 0.5
  static let relativePRNoiseBand = 0.03

  static func prNoiseBand(previousBestKg: Double) -> Double {
    max(minimumPRImprovementKg, previousBestKg * relativePRNoiseBand)
  }
}
