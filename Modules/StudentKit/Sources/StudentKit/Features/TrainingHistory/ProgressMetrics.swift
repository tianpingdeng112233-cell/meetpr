import CoreModels
import Foundation

struct WeeklyProgressMetric: Equatable, Identifiable, Sendable {
  let weekStart: Date
  let volumeKg: Decimal
  let avgRPE: Double?

  var id: Date { weekStart }

  init(weekStart: Date, volumeKg: Decimal, avgRPE: Double?) {
    self.weekStart = weekStart
    self.volumeKg = volumeKg
    self.avgRPE = avgRPE
  }
}

enum ProgressMetrics {
  static func weeklyVolumeIntensity(
    from logs: [StudentSetLog],
    calendar: Calendar = .current
  ) -> [WeeklyProgressMetric] {
    var buckets: [Date: ProgressMetricAccumulator] = [:]

    for log in logs where log.completed {
      guard let weekStart = weekStart(for: log.loggedAt, calendar: calendar) else { continue }
      buckets[weekStart, default: ProgressMetricAccumulator()].add(log)
    }

    return buckets.keys.sorted().map { weekStart in
      let bucket = buckets[weekStart] ?? ProgressMetricAccumulator()
      return WeeklyProgressMetric(
        weekStart: weekStart,
        volumeKg: bucket.volumeKg,
        avgRPE: bucket.averageRPE
      )
    }
  }

  private static func weekStart(for date: Date, calendar: Calendar) -> Date? {
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    guard let start = calendar.date(from: components) else { return nil }
    return calendar.startOfDay(for: start)
  }
}

private struct ProgressMetricAccumulator {
  var volumeKg: Decimal = 0
  var rpeTotal: Decimal = 0
  var rpeCount = 0

  mutating func add(_ log: StudentSetLog) {
    volumeKg += log.weightKg * Decimal(log.reps)
    if let rpe = log.rpe {
      rpeTotal += rpe
      rpeCount += 1
    }
  }

  var averageRPE: Double? {
    guard rpeCount > 0 else { return nil }
    return NSDecimalNumber(decimal: rpeTotal)
      .dividing(by: NSDecimalNumber(value: rpeCount))
      .doubleValue
  }
}
