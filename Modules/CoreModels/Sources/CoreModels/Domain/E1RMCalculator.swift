import Foundation

/// Estimated-1RM math shared by both roles (specs 028 and 106; ADR-005).
/// Source: extended RPE table (JTS / Programming To Win).
public enum E1RMCalculator {
  /// Extended RPE intensity table (% of 1RM), reps 1–12 and RPE 6–10.
  /// Spec 106 extends rows 11–12 using the diagonal pattern and final slope.
  private static let rtsTable: [[Double]] = [
    [0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955, 0.978, 1],
    [0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922, 0.939, 0.955],
    [0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892, 0.907, 0.922],
    [0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863, 0.878, 0.892],
    [0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837, 0.85, 0.863],
    [0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811, 0.824, 0.837],
    [0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786, 0.799, 0.811],
    [0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762, 0.774, 0.786],
    [0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739, 0.751, 0.762],
    [0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707, 0.723, 0.739],
    [0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68, 0.694, 0.707],
    [0.572, 0.5855, 0.599, 0.6125, 0.626, 0.64, 0.653, 0.667, 0.68],
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
