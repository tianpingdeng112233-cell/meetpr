import CoreModels
import Foundation

/// Tunable e1RM aggregation, anomaly, and PR policy parameters (spec 050 §§1–5).
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

  /// Largest jump over the trusted running best that remains a normal point.
  static let softJump = 0.10
  /// Above this jump, Phase 2 will ask the student to confirm the entry.
  static let hardJump = 0.18

  static func prNoiseBand(previousBestKg: Double) -> Double {
    max(minimumPRImprovementKg, previousBestKg * relativePRNoiseBand)
  }

  static func anomalyVerdict(
    newE1RMKg: Double,
    previousBestKg: Double?
  ) -> E1RMAnomalyClassifier.Verdict {
    E1RMAnomalyClassifier.classify(
      newE1RMKg: newE1RMKg,
      priorNormalBestKg: previousBestKg,
      softJump: softJump,
      hardJump: hardJump
    )
  }
}
