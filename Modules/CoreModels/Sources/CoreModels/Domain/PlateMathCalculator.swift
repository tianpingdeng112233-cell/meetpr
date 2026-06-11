import Foundation

/// Barbell plate-loading math (spec 030 §A1). V0.1 locks a 20kg bar with the
/// IPF denomination set, unlimited plates each; custom inventories, lb mode
/// and 15kg bars are V0.1.x. Cross-role pure math lives in CoreModels Domain
/// (E1RMCalculator precedent) — coach-side planning reuse needs no move.
public enum PlateMathCalculator {
  public static let barWeightKg: Double = 20.0
  /// IPF denominations, descending. Every value is a multiple of 1.25
  /// (a sum of negative powers of two), so Double represents them exactly —
  /// the loop below needs no epsilon.
  public static let plateDenominationsKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

  public struct Loadout: Hashable, Sendable {
    public let requestedKg: Double
    public let achievedKg: Double
    /// Per-side plates, heaviest first, duplicates included (e.g. [25, 25, 10, 1.25]).
    public let platesPerSideKg: [Double]
    public var isExact: Bool { achievedKg == requestedKg }

    public init(requestedKg: Double, achievedKg: Double, platesPerSideKg: [Double]) {
      self.requestedKg = requestedKg
      self.achievedKg = achievedKg
      self.platesPerSideKg = platesPerSideKg
    }
  }

  /// Rounding rule (locked): the smallest per-side plate is 1.25kg, so total
  /// weight sits on a 2.5kg grid. Off-grid targets round to the nearest grid
  /// point, ties away from zero (101.25 → 102.5; 101.2 → 100) — never floor:
  /// students reading 102.5 rendered as 100 assume a bug. Targets below the
  /// bare bar return nil.
  public static func loadout(forTargetKg target: Double) -> Loadout? {
    guard target >= barWeightKg else { return nil }
    let steps = ((target - barWeightKg) / 2.5).rounded(.toNearestOrAwayFromZero)
    let achieved = barWeightKg + steps * 2.5
    var remaining = (achieved - barWeightKg) / 2
    var plates: [Double] = []
    for denomination in plateDenominationsKg {
      while remaining >= denomination {
        plates.append(denomination)
        remaining -= denomination
      }
    }
    return Loadout(requestedKg: target, achievedKg: achieved, platesPerSideKg: plates)
  }
}
