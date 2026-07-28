import CoreModels
import Foundation

/// Spec 050 aggregation plus the student-only all-time record projection.
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
  /// One canonical point per eligible training day. Multiple estimates on the
  /// same day collapse to that day's best; low-confidence winners remain here
  /// so point identity stays aligned with the unlock count.
  let dailyBestEligible: [Sample]
  /// Trusted all-time records, chronological and strictly increasing by value.
  let records: [Sample]
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

  /// The shared chart-point identity policy: one best eligible estimate for
  /// each distinct training day. Confidence affects value rendering, not day
  /// identity. Equal values prefer a trusted estimate so an equivalent
  /// low-confidence record cannot demote that day from the main line.
  static func dailyBestEligible(
    points: [E1RMHistoryPoint],
    family: LiftFamily?,
    calendar: Calendar = .current
  ) -> [E1RMHistoryPoint] {
    let pointsByDay = Dictionary(
      grouping: eligibleRaw(points: points, family: family),
      by: { calendar.startOfDay(for: $0.computedAt) }
    )
    return pointsByDay.values.compactMap { pointsForDay in
      pointsForDay.max(by: dailyBestPrecedes)
    }
    .sorted { $0.computedAt < $1.computedAt }
  }

  /// Extends an all-time record series across a chart window. A record already
  /// established before `windowStart` is carried to the leading edge, and the
  /// latest record is carried to `extensionDate` so sparse histories remain
  /// visible. Continuation samples preserve winner provenance but use fresh
  /// timeline identities.
  static func recordTrajectory(
    records: [Sample],
    from windowStart: Date? = nil,
    extendedTo extensionDate: Date
  ) -> [Sample] {
    let sortedRecords = records.sorted { $0.date < $1.date }
    guard let latestRecord = sortedRecords.last else { return [] }

    var usedSampleIDs = Set(sortedRecords.map(\.sampleID))
    var trajectory: [Sample]
    if let windowStart {
      trajectory = sortedRecords.filter { $0.date >= windowStart }
      if let establishedRecord = sortedRecords.last(where: { $0.date <= windowStart }),
        establishedRecord.date < windowStart
      {
        trajectory.insert(
          continuationSample(
            from: establishedRecord,
            date: windowStart,
            usedSampleIDs: &usedSampleIDs
          ),
          at: 0
        )
      }
    } else {
      trajectory = sortedRecords
    }

    if latestRecord.date < extensionDate, trajectory.last?.date != extensionDate {
      trajectory.append(
        continuationSample(
          from: latestRecord,
          date: extensionDate,
          usedSampleIDs: &usedSampleIDs
        )
      )
    }
    return trajectory
  }

  /// Re-expresses samples as history points while retaining their winner's
  /// original set payload and provenance.
  static func historyPoints(
    for samples: [Sample],
    sourcePoints: [E1RMHistoryPoint]
  ) -> [E1RMHistoryPoint] {
    let byID = Dictionary(uniqueKeysWithValues: sourcePoints.map { ($0.id, $0) })
    return samples.compactMap { sample in
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

  static func build(points: [E1RMHistoryPoint], family: LiftFamily?) -> E1RMSeries {
    let eligiblePoints = eligibleRaw(points: points, family: family)
    let rawEligible = eligiblePoints.map(Sample.init(point:))
    let dailyBestEligible = dailyBestEligible(points: points, family: family)
      .map(Sample.init(point:))
    let trusted = eligiblePoints.filter { $0.confidence == .normal }

    var recordValue = -Double.infinity
    let records = trusted.compactMap { point -> Sample? in
      guard point.e1RMKg > recordValue else { return nil }
      recordValue = point.e1RMKg
      return Sample(point: point)
    }

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
      dailyBestEligible: dailyBestEligible,
      records: records,
      best: trusted.max { $0.e1RMKg < $1.e1RMKg }.map(Sample.init(point:)),
      last: trusted.last.map(Sample.init(point:))
    )
  }

  private static func dailyBestPrecedes(
    _ lhs: E1RMHistoryPoint,
    _ rhs: E1RMHistoryPoint
  ) -> Bool {
    if lhs.e1RMKg != rhs.e1RMKg {
      return lhs.e1RMKg < rhs.e1RMKg
    }
    if lhs.confidence != rhs.confidence {
      return lhs.confidence == .low
    }
    return lhs.computedAt < rhs.computedAt
  }

  private static func continuationSample(
    from record: Sample,
    date: Date,
    usedSampleIDs: inout Set<UUID>
  ) -> Sample {
    var sampleID = UUID()
    while usedSampleIDs.contains(sampleID) {
      sampleID = UUID()
    }
    usedSampleIDs.insert(sampleID)
    return Sample(
      sampleID: sampleID,
      date: date,
      valueKg: record.valueKg,
      winnerPointID: record.winnerPointID,
      winnerOrigin: record.winnerOrigin,
      winnerConfidence: record.winnerConfidence
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
