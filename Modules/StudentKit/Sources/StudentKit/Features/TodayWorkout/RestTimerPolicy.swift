import CoreModels
import Foundation

/// RPE → rest seconds, parameters lifted from the JAI auto-timer table
/// (spec 030 §B1). The shared table lives in CoreModels.RestDefaults so coach
/// planning defaults and student fallback stay in lockstep.
enum RestTimerPolicy {
  /// | RPE          | rest |
  /// |--------------|------|
  /// | nil (unset)  | 3min |
  /// | ≤ 6.5        | 2min |
  /// | 7 – 8.5      | 3min | (JAI lists 7-7.5 and 8-8.5 separately, both 3min)
  /// | 9+           | 4min |
  static func restSeconds(forRPE rpe: Decimal?) -> Int {
    RestDefaults.seconds(forRPE: rpe)
  }
}
