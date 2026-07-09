import Foundation

/// Graded anomaly guard for e1RM points (spec 050 §5). A single mis-logged set
/// (P1-1's numeric keyboard makes 175→275 easy to fat-finger) must never poison
/// the headline strength number. Classifies a new e1RM against the prior
/// `.normal` running best — pure cross-role domain math, alongside
/// `E1RMCalculator` / `E1RMPlateauDetector`.
///
/// Bands, relative to prior best B:
/// - `≤ +10%` → `.normal` (real gain / day-to-day noise; PR still gated by §3 band)
/// - `+10%…+18%` → `.lowConfidence` (quarantine: excluded from current/best/PR,
///   kept as honest scatter)
/// - `> +18%` → `.suspectHard` (Phase 2 asks the student to confirm the weight)
///
/// Anchored to strength science: single-session real gains run 0–5% (men gain
/// ~7%/year), so beating an all-time best by >18% in one set is almost always a
/// typo. Product decision:
/// `~/Brain/wiki/projects/MeetPR/domain/e1rm-headline-and-anomaly-guard.md`.
public enum E1RMAnomalyClassifier {
  public enum Verdict: Equatable, Sendable {
    case normal
    case lowConfidence
    case suspectHard
  }

  /// Largest single-session jump over the running best still trusted as a PR.
  public static let softJump = 0.10
  /// Above this, the jump is treated as a suspected mis-log (Phase 2 confirms).
  public static let hardJump = 0.18

  /// - Parameters:
  ///   - newE1RMKg: the just-computed estimate for the new set.
  ///   - priorNormalBestKg: the running best over prior `.normal` points; `nil`
  ///     (or non-positive) on a cold start, which is always `.normal` — there
  ///     is nothing to compare against yet.
  public static func classify(newE1RMKg: Double, priorNormalBestKg: Double?) -> Verdict {
    guard let best = priorNormalBestKg, best > 0 else { return .normal }
    if newE1RMKg <= best * (1 + softJump) { return .normal }
    if newE1RMKg <= best * (1 + hardJump) { return .lowConfidence }
    return .suspectHard
  }
}
