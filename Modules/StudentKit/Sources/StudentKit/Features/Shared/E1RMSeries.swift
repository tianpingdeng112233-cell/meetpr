import CoreModels
import Foundation

/// Which sets are allowed into e1RM estimation (spec 050 §1). The gate only
/// guards e1RM/PR — ineligible sets still log normally.
enum E1RMEligibility {
  /// - rpe: nil is allowed (coached plans often lack actuals; the formula's
  ///   to-failure assumption then reads conservative). RPE < 7 is too far
  ///   from failure for the estimate to mean anything.
  /// - reps: > 10 is the every-formula-fails zone; deadlifts only trust
  ///   reps ≤ 5 (grip/position fatigue ends high-rep sets before muscular
  ///   failure and inflates the estimate).
  static func isEligible(reps: Int, rpe: Double?, family: LiftFamily?) -> Bool {
    if let rpe, rpe < 7 { return false }
    if reps > 10 { return false }
    if family == .deadlift, reps > 5 { return false }
    return true
  }

  static func isEligible(point: E1RMHistoryPoint, family: LiftFamily?) -> Bool {
    isEligible(reps: point.sourceReps, rpe: point.sourceRPE, family: family)
  }
}

/// The one aggregation every "我的实力" consumer reads (spec 050 §2):
/// current = 4-week rolling max over eligible points; the curve draws the
/// rolling-max line with eligible raw points as honest scatter.
struct E1RMSeries: Equatable, Sendable {
  struct Sample: Equatable, Sendable {
    let pointID: UUID
    let date: Date
    let valueKg: Double
  }

  /// Rolling-max value at each eligible point's date, chronological.
  let smoothed: [Sample]
  /// Eligible raw points, chronological (scatter overlay).
  let rawEligible: [Sample]
  /// Highest eligible raw point (historical best, PR reference).
  let best: Sample?
  /// Most recent eligible raw point.
  let last: Sample?

  var currentKg: Double? { smoothed.last?.valueKg }

  static let rollingWindow: TimeInterval = 28 * 86_400  // 4 weeks (工程常量)

  static func build(points: [E1RMHistoryPoint], family: LiftFamily?) -> E1RMSeries {
    let eligible =
      points
      .filter { E1RMEligibility.isEligible(point: $0, family: family) }
      .sorted { $0.computedAt < $1.computedAt }
      .map { Sample(pointID: $0.id, date: $0.computedAt, valueKg: $0.e1RMKg) }

    let smoothed = eligible.map { sample in
      let windowStart = sample.date.addingTimeInterval(-rollingWindow)
      let windowMax =
        eligible
        .filter { $0.date > windowStart && $0.date <= sample.date }
        .map(\.valueKg)
        .max() ?? sample.valueKg
      return Sample(pointID: sample.pointID, date: sample.date, valueKg: windowMax)
    }

    return E1RMSeries(
      smoothed: smoothed,
      rawEligible: eligible,
      best: eligible.max { $0.valueKg < $1.valueKg },
      last: eligible.last
    )
  }
}
