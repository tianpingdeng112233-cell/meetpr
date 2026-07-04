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

  /// The smoothed series re-expressed as history points (ids preserved from
  /// the underlying samples) so existing polyline/sparkline consumers switch
  /// data sources without reshaping (spec 050 §2). Raw-scatter overlay is a
  /// follow-up (F-030 家族).
  static func smoothedHistory(points: [E1RMHistoryPoint], family: LiftFamily?)
    -> [E1RMHistoryPoint]
  {
    let byID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
    return build(points: points, family: family).smoothed.compactMap { sample in
      guard let original = byID[sample.pointID] else { return nil }
      return E1RMHistoryPoint(
        id: original.id,
        studentId: original.studentId,
        exerciseId: original.exerciseId,
        setLogId: original.setLogId,
        computedAt: sample.date,
        e1RMKg: sample.valueKg,
        sourceWeightKg: original.sourceWeightKg,
        sourceReps: original.sourceReps,
        sourceRPE: original.sourceRPE
      )
    }
  }

  /// Eligibility-filtered raw points (Best/Last keep honest raw semantics).
  static func eligibleRaw(points: [E1RMHistoryPoint], family: LiftFamily?)
    -> [E1RMHistoryPoint]
  {
    points
      .filter { E1RMEligibility.isEligible(point: $0, family: family) }
      .sorted { $0.computedAt < $1.computedAt }
  }

  static func build(points: [E1RMHistoryPoint], family: LiftFamily?) -> E1RMSeries {
    let eligiblePoints =
      points
      .filter { E1RMEligibility.isEligible(point: $0, family: family) }
      .sorted { $0.computedAt < $1.computedAt }
    let rawEligible = eligiblePoints.map {
      Sample(pointID: $0.id, date: $0.computedAt, valueKg: $0.e1RMKg)
    }

    // Anomaly guard (spec 050 §5): current/best/last trust only `.normal`
    // points; `.low` (quarantined) points stay in rawEligible as honest scatter
    // but never become the headline — a rolling max can't dampen an upward
    // spike, this exclusion can.
    let trusted =
      eligiblePoints
      .filter { $0.confidence == .normal }
      .map { Sample(pointID: $0.id, date: $0.computedAt, valueKg: $0.e1RMKg) }

    let smoothed = trusted.map { sample in
      let windowStart = sample.date.addingTimeInterval(-rollingWindow)
      let windowMax =
        trusted
        .filter { $0.date > windowStart && $0.date <= sample.date }
        .map(\.valueKg)
        .max() ?? sample.valueKg
      return Sample(pointID: sample.pointID, date: sample.date, valueKg: windowMax)
    }

    return E1RMSeries(
      smoothed: smoothed,
      rawEligible: rawEligible,
      best: trusted.max { $0.valueKg < $1.valueKg },
      last: trusted.last
    )
  }
}
