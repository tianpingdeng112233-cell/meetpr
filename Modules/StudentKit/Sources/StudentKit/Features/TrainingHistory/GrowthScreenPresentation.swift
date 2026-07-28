import CoreModels
import Foundation

enum GrowthTimeRange: String, CaseIterable, Equatable, Sendable {
  case thirtyDays = "30天"
  case ninetyDays = "90天"
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
    case .all:
      .all
    }
  }
}

enum GrowthE1RMCardState: Equatable, Sendable {
  case chart
  case formingProgress
  case formingWindowSparse
  case zero
}

enum GrowthE1RMCardPolicy {
  static func state(
    windowDataPointCount: Int,
    familyTotalDataPointCount: Int,
    windowMainLinePointCount: Int,
    windowMainLineValueRangeKg: Double?
  ) -> GrowthE1RMCardState {
    let totalCount = max(0, familyTotalDataPointCount)
    let windowCount = min(max(0, windowDataPointCount), totalCount)
    let mainLineCount = min(max(0, windowMainLinePointCount), windowCount)

    if totalCount == 0 {
      return .zero
    }
    if totalCount < GrowthHistoryStats.trendUnlockThreshold {
      return .formingProgress
    }
    if mainLineCount < GrowthHistoryStats.trendUnlockThreshold {
      return .formingWindowSparse
    }
    guard let windowMainLineValueRangeKg, windowMainLineValueRangeKg > 0 else {
      return .formingWindowSparse
    }
    return .chart
  }
}

enum GrowthE1RMCardCopy {
  // David 2026-07-28 provisional wording; keep this as the single edit point
  // until product review confirms it.
  static let windowSparseMessageTemplate =
    "近 {window} 数据不足 · 切到更长时间范围查看"

  static func windowSparseMessage(window: String) -> String {
    windowSparseMessageTemplate.replacing("{window}", with: window)
  }
}

struct GrowthCurveSnapshot: Equatable, Sendable {
  let family: LiftFamily
  let samples: [E1RMSeries.Sample]
  let rawEligiblePoints: [E1RMHistoryPoint]
  let windowDataPointCount: Int
  let eligibleDataPointCount: Int
  let currentKg: Double?
  let deltaKg: Double?
  let latestRecordDate: Date?
  let chartCurrentPoint: E1RMHistoryPoint?

  var cardState: GrowthE1RMCardState {
    GrowthE1RMCardPolicy.state(
      windowDataPointCount: windowDataPointCount,
      familyTotalDataPointCount: eligibleDataPointCount,
      windowMainLinePointCount: samples.count,
      windowMainLineValueRangeKg: windowMainLineValueRangeKg
    )
  }

  private var windowMainLineValueRangeKg: Double? {
    let values = samples.map(\.valueKg)
    guard let minimum = values.min(), let maximum = values.max() else {
      return nil
    }
    return maximum - minimum
  }

  static func empty(family: LiftFamily) -> GrowthCurveSnapshot {
    GrowthCurveSnapshot(
      family: family,
      samples: [],
      rawEligiblePoints: [],
      windowDataPointCount: 0,
      eligibleDataPointCount: 0,
      currentKg: nil,
      deltaKg: nil,
      latestRecordDate: nil,
      chartCurrentPoint: nil
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
    now _: Date = Date()
  ) -> GrowthCurveSnapshot {
    viewModel.selectedFamily = family
    viewModel.selectedWindow = range.timeWindow

    let samples = viewModel.visibleDailyBestSamples
    let rawEligiblePoints = viewModel.visibleRawEligiblePoints
    let headlinePoint = viewModel.headlinePoint(for: family)
    let chartCurrentPoint = samples.last.flatMap(viewModel.sourcePoint(for:))
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
      windowDataPointCount: viewModel.visibleDataPointCount(for: family),
      eligibleDataPointCount: viewModel.eligibleDataPointCount(for: family),
      currentKg: headlinePoint?.e1RMKg,
      deltaKg: deltaKg,
      latestRecordDate: headlinePoint?.computedAt
        ?? rawEligiblePoints.map(\.computedAt).max(),
      chartCurrentPoint: chartCurrentPoint
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

}

private struct GrowthWeekID: Hashable {
  let year: Int
  let week: Int
}
