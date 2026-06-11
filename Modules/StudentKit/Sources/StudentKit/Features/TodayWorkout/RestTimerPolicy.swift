import Foundation

/// RPE → rest seconds, parameters lifted from the JAI auto-timer table
/// (spec 030 §B1). Student-side UX tuning, not cross-role domain math, so it
/// stays in StudentKit. Changing the table = change here + fixtures; these
/// constants must not appear anywhere else.
enum RestTimerPolicy {
  /// | RPE          | rest |
  /// |--------------|------|
  /// | nil (unset)  | 3min |
  /// | ≤ 6.5        | 2min |
  /// | 7 – 8.5      | 3min | (JAI lists 7-7.5 and 8-8.5 separately, both 3min)
  /// | 9+           | 4min |
  static func restSeconds(forRPE rpe: Decimal?) -> Int {
    guard let rpe else { return 180 }
    if rpe < 7 { return 120 }
    if rpe < 9 { return 180 }
    return 240
  }
}
