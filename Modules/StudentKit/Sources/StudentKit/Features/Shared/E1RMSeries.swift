import CoreModels
import Foundation

/// The single aggregation every strength-number consumer reads (spec 050 §2).
/// Current is the trailing four-week max over trusted eligible points; Best
/// and Last use that same history. Quarantined points remain raw scatter only.
struct E1RMSeries: Equatable, Sendable {
  struct Sample: Equatable, Sendable {
    /// Timeline identity for this sample. It remains unique while one raw
    /// point wins several consecutive rolling windows.
    let sampleID: UUID
    let date: Date
    let valueKg: Double
    /// Provenance of the raw point that won this sample's rolling window.
    let winnerPointID: UUID
    let winnerOrigin: E1RMPointOrigin
    let winnerConfidence: E1RMConfidence
  }

  /// Rolling-max value at every eligible point's date, chronological.
  let smoothed: [Sample]
  /// Eligible raw points, chronological, available for honest scatter views.
  let rawEligible: [Sample]
  /// Highest eligible raw point across all history.
  let best: Sample?
  /// Most recent eligible raw point.
  let last: Sample?

  var currentKg: Double? { smoothed.last?.valueKg }

  static let rollingWindow = E1RMPolicy.rollingWindow

  /// Re-expresses the smoothed series as history points so the release/1.0
  /// chart components can change their data source without changing layout.
  static func smoothedHistory(
    points: [E1RMHistoryPoint],
    family: LiftFamily?
  ) -> [E1RMHistoryPoint] {
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

  /// All eligible raw points, including quarantined honest-scatter samples.
  static func eligibleRaw(
    points: [E1RMHistoryPoint],
    family: LiftFamily?
  ) -> [E1RMHistoryPoint] {
    points
      .filter { E1RMEligibility.isEligible(point: $0, family: family) }
      .sorted { $0.computedAt < $1.computedAt }
  }

  /// Eligible points trusted for current, Best, Last, and PR baselines.
  static func trustedEligibleRaw(
    points: [E1RMHistoryPoint],
    family: LiftFamily?
  ) -> [E1RMHistoryPoint] {
    eligibleRaw(points: points, family: family)
      .filter { $0.confidence == .normal }
  }

  static func build(points: [E1RMHistoryPoint], family: LiftFamily?) -> E1RMSeries {
    let eligiblePoints = eligibleRaw(points: points, family: family)
    let rawEligible = eligiblePoints.map(Sample.init(point:))
    let trusted = eligiblePoints.filter { $0.confidence == .normal }

    let smoothed = trusted.map { samplePoint in
      let windowStart = samplePoint.computedAt.addingTimeInterval(-rollingWindow)
      let winner =
        trusted
        .filter {
          $0.computedAt > windowStart && $0.computedAt <= samplePoint.computedAt
        }
        .reduce(samplePoint) { winner, candidate in
          if candidate.e1RMKg > winner.e1RMKg {
            return candidate
          }
          if candidate.e1RMKg == winner.e1RMKg,
            candidate.computedAt < winner.computedAt
          {
            return candidate
          }
          return winner
        }
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
