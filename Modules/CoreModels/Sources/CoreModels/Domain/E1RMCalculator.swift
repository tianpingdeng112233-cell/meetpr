import Foundation

/// Estimated-1RM math shared by both roles (spec 028; ADR-005 §1 cross-role
/// domain). Source of truth is the RTS (Reactive Training Systems) RPE
/// intensity table — NOT a single linear formula: the table's slope differs
/// between reps 1-4 (-4%/rep) and reps 5+ (-2%/rep), so a linear fit drifts
/// up to 6% at reps=5 RPE=10.
public enum E1RMCalculator {
  /// RTS RPE intensity table (% of 1RM). Rows: reps 1-12. Columns: RPE 6.0
  /// to 10.0 in 0.5 steps. Do not replace with Epley/Brzycki/Lombardi/Wathan
  /// or a linear formula (spec 028 §2 lock).
  private static let rtsTable: [[Double]] = [
    // RPE:    6.0   6.5   7.0   7.5   8.0   8.5   9.0   9.5   10.0
    [0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96, 0.98, 1.00],
    [0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.96],
    [0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92],
    [0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86, 0.88],
    [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84, 0.86],
    [0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.84],
    [0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82],
    [0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78, 0.80],
    [0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78],
    [0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76],
    [0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74],
    [0.56, 0.58, 0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72],
  ]

  /// RPE boundary rules (spec 028 §2, locked by PR #116 second-pass review):
  /// - rpe == nil            → Epley fallback
  /// - rpe < 6.0             → Epley fallback (RTS unreliable below 6; sub-maximal input is legitimate)
  /// - 6.0 ... 10.0          → RTS lookup, linear interpolation between 0.5 columns
  /// - rpe > 10.0            → nil (physically invalid; never silently fall back)
  public static func calculate(
    weightKg: Double,
    reps: Int,
    rpe: Double?
  ) -> Double? {
    guard weightKg > 0, reps >= 1 else { return nil }

    if let rpe {
      if rpe > 10.0 { return nil }
      if rpe >= 6.0 {
        let safeReps = min(reps, 12)
        let intensity = rtsIntensity(reps: safeReps, rpe: rpe)
        guard intensity > 0.5 else { return nil }
        return weightKg / intensity
      }
    }

    // Epley fallback: rpe == nil OR rpe in [0, 6.0). Reps beyond the
    // hypertrophy ceiling have no meaningful 1RM estimate.
    guard reps <= 20 else { return nil }
    return weightKg * (1.0 + Double(reps) / 30.0)
  }

  /// Reverses the RTS table to suggest a working weight for an RPE-based
  /// prescription. RPE 5.0...5.5 extends the table's 0.5-step slope below
  /// the first column; values below 5 are outside the app's input range.
  public static func suggestedWeight(
    e1RM: Double,
    reps: Int,
    rpe: Double
  ) -> Double? {
    guard e1RM.isFinite, e1RM > 0, rpe.isFinite, (1...12).contains(reps),
      (5.0...10.0).contains(rpe)
    else {
      return nil
    }

    let result = e1RM * rtsIntensity(reps: reps, rpe: rpe)
    return result.isFinite && result > 0 ? result : nil
  }

  /// 1-D linear interpolation along the RPE axis only — reps are integral
  /// (students log whole reps), so no interpolation across rows.
  private static func rtsIntensity(reps: Int, rpe: Double) -> Double {
    let row = rtsTable[reps - 1]
    if rpe < 6.0 {
      let halfStepSlope = row[1] - row[0]
      return row[0] + ((rpe - 6.0) / 0.5) * halfStepSlope
    }

    let rpeFloat = (rpe - 6.0) / 0.5
    let lower = Int(rpeFloat.rounded(.down))
    let upper = min(lower + 1, 8)
    let fraction = rpeFloat - Double(lower)
    return row[lower] * (1 - fraction) + row[upper] * fraction
  }
}
