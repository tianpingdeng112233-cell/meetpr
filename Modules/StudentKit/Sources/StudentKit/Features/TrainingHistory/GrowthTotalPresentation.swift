import CoreModels
import Foundation

struct GrowthTotalPoint: Equatable, Sendable {
  let date: Date
  let valueKg: Double
}

struct GrowthTotalPresentation: Equatable, Sendable {
  enum State: Equatable, Sendable {
    case missing
    case sparse
    case chart
  }

  let samples: [GrowthTotalPoint]
  let missing: [LiftFamily]
  let currentKg: Double?
  let deltaKg: Double?
  let state: State

  /// Call with All history snapshots, never record trajectories or range-filtered snapshots.
  static func make(
    snapshots: [GrowthCurveSnapshot], range: GrowthTimeRange,
    now: Date = Date(), calendar: Calendar = .current
  ) -> Self {
    let families = MainLiftExerciseFamilyResolver.dashboardFamilies
    let byFamily = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.family, $0) })
    let missing = families.filter { byFamily[$0]?.samples.isEmpty ?? true }
    let updates = snapshots.flatMap { snapshot in
      snapshot.samples.filter { $0.winnerConfidence == .normal }.map { (snapshot.family, $0) }
    }.sorted { $0.1.date < $1.1.date }
    var latest: [LiftFamily: Double] = [:]
    var days: [Date: GrowthTotalPoint] = [:]
    for (family, sample) in updates {
      latest[family] = sample.valueKg
      if families.allSatisfy({ latest[$0] != nil }) {
        days[calendar.startOfDay(for: sample.date)] = GrowthTotalPoint(
          date: sample.date, valueKg: families.compactMap { latest[$0] }.reduce(0, +))
      }
    }
    let cutoff: Date?
    switch range {
    case .thirtyDays: cutoff = now.addingTimeInterval(-E1RMPolicy.rollingWindow)
    case .ninetyDays: cutoff = now.addingTimeInterval(-90 * 86_400)
    case .all: cutoff = nil
    }
    let samples = days.values.sorted { $0.date < $1.date }.filter { point in
      cutoff.map { point.date >= $0 } ?? true
    }
    let headlines = families.compactMap { byFamily[$0]?.currentKg }
    let values = samples.map(\.valueKg)
    return Self(
      samples: samples, missing: missing,
      currentKg: headlines.count == families.count ? headlines.reduce(0, +) : nil,
      deltaKg: samples.count > 1 ? (values.last ?? 0) - (values.first ?? 0) : nil,
      state: !missing.isEmpty
        ? .missing
        : samples.count < 3 || values.min() == values.max()
          ? .sparse : .chart
    )
  }
}
