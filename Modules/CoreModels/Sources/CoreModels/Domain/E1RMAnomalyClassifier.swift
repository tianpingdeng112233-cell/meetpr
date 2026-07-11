import Foundation

/// Classifies a new e1RM against the prior trusted best so recording code can
/// quarantine physiologically implausible jumps (spec 050 §5).
public enum E1RMAnomalyClassifier {
  public enum Verdict: Equatable, Sendable {
    case normal
    case lowConfidence
    case suspectHard
  }

  /// A cold start is trusted because there is no personal history to compare.
  /// Product thresholds belong to the caller's policy rather than this pure
  /// cross-role calculation.
  public static func classify(
    newE1RMKg: Double,
    priorNormalBestKg: Double?,
    softJump: Double,
    hardJump: Double
  ) -> Verdict {
    guard let best = priorNormalBestKg, best > 0 else { return .normal }
    if newE1RMKg <= best * (1 + softJump) { return .normal }
    if newE1RMKg <= best * (1 + hardJump) { return .lowConfidence }
    return .suspectHard
  }
}
