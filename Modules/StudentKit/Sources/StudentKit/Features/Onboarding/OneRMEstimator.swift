import CoreModels
import Foundation

/// Step 3 estimator math (spec 032 D7): wraps the spec-028 `E1RMCalculator`
/// (RTS table — no new math) and produces the two fill-in options, snapped
/// to the 0.5 kg grid. The conservative value is 90% of the *unrounded*
/// estimate (wiki v2.3 issue 5), rounded last.
public enum OneRMEstimator {
  public struct Estimate: Equatable, Sendable {
    /// e1RM on the 0.5 kg grid.
    public let estimated: Decimal
    /// 90% of the raw e1RM, 0.5 kg grid.
    public let conservative: Decimal
  }

  public static func estimate(weightKg: Double, reps: Int, rpe: Double?) -> Estimate? {
    guard let raw = E1RMCalculator.calculate(weightKg: weightKg, reps: reps, rpe: rpe) else {
      return nil
    }
    return Estimate(
      estimated: snapped(raw),
      conservative: snapped(raw * 0.9)
    )
  }

  /// Round to the nearest 0.5 kg.
  static func snapped(_ value: Double) -> Decimal {
    Decimal((value * 2).rounded() / 2)
  }
}
