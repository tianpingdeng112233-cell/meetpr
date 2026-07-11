import CoreModels
import Foundation

/// The single aggregation every strength-number consumer reads (spec 050 §2).
/// Current is the trailing four-week max over eligible points; Best and Last
/// preserve their raw meanings over that same eligible history.
struct E1RMSeries: Equatable, Sendable {
  struct Sample: Equatable, Sendable {
    let pointID: UUID
    let date: Date
    let valueKg: Double
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

  /// Eligible raw points used by Last/Best references and PR baselines.
  static func eligibleRaw(
    points: [E1RMHistoryPoint],
    family: LiftFamily?
  ) -> [E1RMHistoryPoint] {
    points
      .filter { E1RMEligibility.isEligible(point: $0, family: family) }
      .sorted { $0.computedAt < $1.computedAt }
  }

  static func build(points: [E1RMHistoryPoint], family: LiftFamily?) -> E1RMSeries {
    let eligible = eligibleRaw(points: points, family: family).map {
      Sample(pointID: $0.id, date: $0.computedAt, valueKg: $0.e1RMKg)
    }

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
