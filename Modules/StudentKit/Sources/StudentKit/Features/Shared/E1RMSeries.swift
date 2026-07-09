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
    /// The timestamp sample identity. It stays distinct even while the same
    /// rolling-window winner carries across successive days.
    let sampleID: UUID
    let date: Date
    let valueKg: Double
    /// The raw point that won this sample's rolling window. Its provenance is
    /// deliberately separate from the sample's x-axis date (spec 053 §6).
    let winnerPointID: UUID
    let winnerOrigin: E1RMPointOrigin
    let winnerConfidence: E1RMConfidence
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

  /// The smoothed series re-expressed as history points so legacy
  /// polyline/sparkline consumers can continue consuming domain points. The
  /// sample uses its own identity while the raw set payload/provenance comes
  /// from the rolling-window winner (spec 053 §6).
  static func smoothedHistory(points: [E1RMHistoryPoint], family: LiftFamily?)
    -> [E1RMHistoryPoint]
  {
    let byID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
    return build(points: points, family: family).smoothed.compactMap { sample in
      guard let winner = byID[sample.winnerPointID] else { return nil }
      return E1RMHistoryPoint(
        id: sample.sampleID,
        studentId: winner.studentId,
        exerciseId: winner.exerciseId,
        setLogId: winner.setLogId,
        computedAt: sample.date,
        e1RMKg: sample.valueKg,
        sourceWeightKg: winner.sourceWeightKg,
        sourceReps: winner.sourceReps,
        sourceRPE: winner.sourceRPE,
        confidence: sample.winnerConfidence,
        origin: sample.winnerOrigin
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
    let rawEligible = eligiblePoints.map(Sample.init(point:))

    // Anomaly guard (spec 050 §5): current/best/last trust only `.normal`
    // points; `.low` (quarantined) points stay in rawEligible as honest scatter
    // but never become the headline — a rolling max can't dampen an upward
    // spike, this exclusion can.
    let trusted = eligiblePoints.filter { $0.confidence == .normal }

    let smoothed = trusted.map { samplePoint in
      let windowStart = samplePoint.computedAt.addingTimeInterval(-rollingWindow)
      let winner =
        trusted
        .filter { $0.computedAt > windowStart && $0.computedAt <= samplePoint.computedAt }
        .max { lhs, rhs in
          lhs.e1RMKg == rhs.e1RMKg
            ? lhs.computedAt < rhs.computedAt : lhs.e1RMKg < rhs.e1RMKg
        } ?? samplePoint
      return Sample(
        sampleID: samplePoint.id,
        date: samplePoint.computedAt,
        valueKg: winner.e1RMKg,
        winnerPointID: winner.id,
        winnerOrigin: winner.origin,
        winnerConfidence: winner.confidence
      )
    }

    return E1RMSeries(
      smoothed: smoothed,
      rawEligible: rawEligible,
      best: trusted.max { $0.e1RMKg < $1.e1RMKg }.map(Sample.init(point:)),
      last: trusted.last.map(Sample.init(point:))
    )
  }
}

extension E1RMSeries.Sample {
  fileprivate init(point: E1RMHistoryPoint) {
    self.init(
      sampleID: point.id,
      date: point.computedAt,
      valueKg: point.e1RMKg,
      winnerPointID: point.id,
      winnerOrigin: point.origin,
      winnerConfidence: point.confidence
    )
  }
}
