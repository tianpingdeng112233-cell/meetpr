import CoreModels
import Foundation

extension DraftSetSpec {
  /// "已填" from the coach's perspective: the load is actually set, not just
  /// that a default spec row exists (David 2026-06-14 — a freshly added
  /// accessory showed 已填 with weight 0). Weight mode needs a positive
  /// weight; RPE mode a 1–10 value; both need ≥1 set / ≥1 rep with a
  /// non-inverted reps range.
  ///
  /// Stricter than `isValidSetSpec` (which tolerates weight 0 so an untouched
  /// exercise doesn't block step navigation): this drives the 已填 badge and
  /// the pre-publish completeness check (Step 4 完成 + 发布).
  var isCoachComplete: Bool {
    if let perSetTargets {
      guard setCount >= 1, perSetTargets.count == setCount else { return false }
      return perSetTargets.allSatisfy { target in
        guard target.targetReps >= 1 else { return false }
        if let targetRepsMax = target.targetRepsMax, targetRepsMax < target.targetReps {
          return false
        }
        switch target.intensityMode {
        case .weight:
          return target.targetValue > 0
        case .rpe:
          return target.targetValue >= 1 && target.targetValue <= 10
        }
      }
    }

    guard setCount >= 1, targetReps >= 1 else { return false }
    if let targetRepsMax, targetRepsMax < targetReps { return false }
    switch intensityMode {
    case .weight:
      return targetValue > 0
    case .rpe:
      return targetValue >= 1 && targetValue <= 10
    }
  }
}
