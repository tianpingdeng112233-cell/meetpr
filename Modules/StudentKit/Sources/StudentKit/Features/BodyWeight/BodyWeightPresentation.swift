import Foundation

struct BodyWeightPresentation: Equatable, Sendable {
  enum State: Equatable, Sendable { case empty, single, chart }

  let records: [BodyWeightRecord]
  let points: [BodyWeightRecord]
  let currentKg: Decimal?
  let deltaKg: Decimal?
  let hasToday: Bool
  let state: State

  init(records: [BodyWeightRecord], range: GrowthTimeRange, now: Date = Date()) {
    let ascending = records.sorted { $0.recordedOn < $1.recordedOn }
    self.records = ascending.reversed()
    currentKg = ascending.last?.weightKg
    let today = BodyWeightDay.string(from: now)
    hasToday = ascending.contains { $0.recordedOn == today }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    let days = range == .thirtyDays ? 30 : 90
    let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: now) ?? now
    let cutoffDay = BodyWeightDay.string(from: cutoff)
    points = ascending.filter { range == .all || $0.recordedOn >= cutoffDay }
    if points.count > 1, let first = points.first, let last = points.last {
      deltaKg = last.weightKg - first.weightKg
    } else {
      deltaKg = nil
    }
    state = points.isEmpty ? .empty : points.count == 1 ? .single : .chart
  }
}
