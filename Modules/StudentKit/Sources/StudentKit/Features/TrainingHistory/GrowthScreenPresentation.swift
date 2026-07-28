import CoreModels
import Foundation

enum GrowthTimeRange: String, CaseIterable, Equatable, Sendable {
  case thirtyDays = "30天"
  case ninetyDays = "90天"
  case oneYear = "1年"
  case all = "历史总览"

  init(timeWindow: GrowthCurveViewModel.TimeWindow) {
    switch timeWindow {
    case .fourWeeks:
      self = .thirtyDays
    case .threeMonths:
      self = .ninetyDays
    case .all:
      self = .all
    }
  }

  var timeWindow: GrowthCurveViewModel.TimeWindow {
    switch self {
    case .thirtyDays:
      .fourWeeks
    case .ninetyDays:
      .threeMonths
    case .oneYear, .all:
      .all
    }
  }

  func cutoff(now: Date) -> Date? {
    switch self {
    case .oneYear:
      now.addingTimeInterval(-365 * 86_400)
    case .thirtyDays, .ninetyDays, .all:
      nil
    }
  }
}

struct GrowthCurveSnapshot: Equatable, Sendable {
  let family: LiftFamily
  let samples: [E1RMSeries.Sample]
  let rawEligiblePoints: [E1RMHistoryPoint]
  let eligibleRecordCount: Int
  let currentKg: Double?
  let deltaKg: Double?
  let latestRecordDate: Date?
  let latestRecordPoint: E1RMHistoryPoint?

  var isFormingTrend: Bool {
    eligibleRecordCount > 0
      && eligibleRecordCount < GrowthHistoryStats.trendUnlockThreshold
  }

  static func empty(family: LiftFamily) -> GrowthCurveSnapshot {
    GrowthCurveSnapshot(
      family: family,
      samples: [],
      rawEligiblePoints: [],
      eligibleRecordCount: 0,
      currentKg: nil,
      deltaKg: nil,
      latestRecordDate: nil,
      latestRecordPoint: nil
    )
  }
}

struct GrowthComparisonRow: Equatable, Identifiable, Sendable {
  let family: LiftFamily
  let estimatedOneRepMaxKg: Double?
  let trainingOneRepMaxKg: Decimal?

  var id: LiftFamily { family }

  var progress: Double {
    guard let estimatedOneRepMaxKg,
      let trainingOneRepMaxKg,
      trainingOneRepMaxKg > 0
    else {
      return 0
    }
    return min(estimatedOneRepMaxKg / NSDecimalNumber(decimal: trainingOneRepMaxKg).doubleValue, 1)
  }

  var percentage: Int? {
    guard let estimatedOneRepMaxKg,
      let trainingOneRepMaxKg,
      trainingOneRepMaxKg > 0
    else {
      return nil
    }
    let training = NSDecimalNumber(decimal: trainingOneRepMaxKg).doubleValue
    return Int((estimatedOneRepMaxKg / training * 100).rounded())
  }

  var hasExceededTrainingBaseline: Bool {
    guard let percentage else { return false }
    return percentage >= 100
  }
}

struct GrowthComparisonPresentation: Equatable, Sendable {
  let rows: [GrowthComparisonRow]

  var estimatedTotalKg: Double? {
    let values = rows.compactMap(\.estimatedOneRepMaxKg)
    guard values.count == rows.count else { return nil }
    return values.reduce(0, +)
  }

  var trainingTotalKg: Decimal? {
    let values = rows.compactMap(\.trainingOneRepMaxKg)
    guard values.count == rows.count else { return nil }
    return values.reduce(0, +)
  }

  static func make(
    snapshots: [GrowthCurveSnapshot],
    onboarding: OnboardingProfile?
  ) -> GrowthComparisonPresentation {
    let currentByFamily = Dictionary(
      uniqueKeysWithValues: snapshots.map { ($0.family, $0.currentKg) }
    )
    let trainingByFamily: [LiftFamily: Decimal?] = [
      .squat: onboarding?.squat1RMKg,
      .bench: onboarding?.bench1RMKg,
      .deadlift: onboarding?.deadlift1RMKg,
    ]
    return GrowthComparisonPresentation(
      rows: MainLiftExerciseFamilyResolver.dashboardFamilies.map { family in
        GrowthComparisonRow(
          family: family,
          estimatedOneRepMaxKg: currentByFamily[family].flatMap { $0 },
          trainingOneRepMaxKg: trainingByFamily[family].flatMap { $0 }
        )
      }
    )
  }
}

struct GrowthHistoryStats: Equatable, Sendable {
  static let trendUnlockThreshold = 3

  let trainingSessionCount: Int
  let trainingWeekCount: Int
  let totalVolumeKg: Decimal

  var unlocksTrends: Bool {
    trainingSessionCount >= Self.trendUnlockThreshold
  }
}

enum GrowthScreenPresentation {
  @MainActor
  static func snapshot(
    from viewModel: GrowthCurveViewModel,
    family: LiftFamily,
    range: GrowthTimeRange,
    now: Date = Date()
  ) -> GrowthCurveSnapshot {
    viewModel.selectedFamily = family
    viewModel.selectedWindow = range.timeWindow

    let samples = samples(
      viewModel.visibleSmoothedSamples,
      cutoff: range.cutoff(now: now)
    )
    let rawEligiblePoints = viewModel.visibleRawEligiblePoints.filter { point in
      range.cutoff(now: now).map { point.computedAt >= $0 } ?? true
    }
    let latestRecordPoint = viewModel.visibleSmoothedSamples.last.flatMap {
      viewModel.winnerPoint(forSampleID: $0.sampleID)
    }
    let deltaKg: Double?
    if let first = samples.first, let last = samples.last, samples.count > 1 {
      deltaKg = last.valueKg - first.valueKg
    } else {
      deltaKg = nil
    }

    return GrowthCurveSnapshot(
      family: family,
      samples: samples,
      rawEligiblePoints: rawEligiblePoints,
      eligibleRecordCount: viewModel.eligibleRecordCount(for: family),
      currentKg: latestRecordPoint?.e1RMKg,
      deltaKg: deltaKg,
      latestRecordDate: latestRecordPoint?.computedAt
        ?? rawEligiblePoints.map(\.computedAt).max(),
      latestRecordPoint: latestRecordPoint
    )
  }

  static func historyStats(
    logs: [StudentSetLog],
    calendar: Calendar = .current
  ) -> GrowthHistoryStats {
    let completed = logs.filter { $0.completed && !$0.assumed }
    let sessionDays = Set(completed.map { calendar.startOfDay(for: $0.loggedAt) })
    let weekIDs = Set(
      completed.map { log in
        let components = calendar.dateComponents(
          [.yearForWeekOfYear, .weekOfYear],
          from: log.loggedAt
        )
        return GrowthWeekID(
          year: components.yearForWeekOfYear ?? 0,
          week: components.weekOfYear ?? 0
        )
      }
    )
    let volume = completed.reduce(Decimal.zero) { total, log in
      total + log.weightKg * Decimal(log.reps)
    }
    return GrowthHistoryStats(
      trainingSessionCount: sessionDays.count,
      trainingWeekCount: weekIDs.count,
      totalVolumeKg: volume
    )
  }

  static func chartBuckets(
    logs: [StudentSetLog],
    calendar: Calendar = .current,
    maximumCount: Int = 6
  ) -> [WeeklyProgressMetric] {
    Array(
      ProgressMetrics.weeklyVolumeIntensity(from: logs, calendar: calendar)
        .suffix(max(0, maximumCount))
    )
  }

  private static func samples(
    _ samples: [E1RMSeries.Sample],
    cutoff: Date?
  ) -> [E1RMSeries.Sample] {
    guard let cutoff else { return samples }

    var visible = samples.filter { $0.date >= cutoff }
    if let carry = samples.last(where: { $0.date < cutoff }) {
      visible.insert(
        E1RMSeries.Sample(
          sampleID: UUID(),
          date: cutoff,
          valueKg: carry.valueKg,
          winnerPointID: carry.winnerPointID,
          winnerOrigin: carry.winnerOrigin,
          winnerConfidence: carry.winnerConfidence
        ),
        at: 0
      )
    }
    return visible
  }
}

private struct GrowthWeekID: Hashable {
  let year: Int
  let week: Int
}
