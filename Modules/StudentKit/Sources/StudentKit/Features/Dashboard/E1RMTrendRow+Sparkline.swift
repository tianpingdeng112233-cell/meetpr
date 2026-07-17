import CoreGraphics
import CoreModels
import Foundation

/// Shared mapping of an e1RM trend row into sparkline geometry + its 90-day
/// delta, used by both the 今日 home and the 成长 growth page so the two never
/// drift. Pure geometry — no view layer.
extension DashboardE1RMTrendRow {
  var sortedPoints: [E1RMHistoryPoint] {
    points.sorted { $0.computedAt < $1.computedAt }
  }

  /// Last − first e1RM over the loaded window; `nil` when there is < 2 points.
  var trendDeltaKg: Double? {
    let sorted = sortedPoints
    guard sorted.count > 1, let first = sorted.first?.e1RMKg, let last = sorted.last?.e1RMKg else {
      return nil
    }
    return last - first
  }

  /// Points mapped into a `width`×(`top`+`usableHeight`+`top`) view-box, with
  /// high values near the top (SwiftUI y grows downward).
  func sparklinePoints(width: Double = 600, top: Double = 10, usableHeight: Double = 100)
    -> [CGPoint]
  {
    let sorted = sortedPoints
    guard !sorted.isEmpty else { return [] }
    let values = sorted.map(\.e1RMKg)
    let minValue = values.min() ?? 0
    let maxValue = values.max() ?? minValue
    let span = Swift.max(maxValue - minValue, 1)
    // Records connect with plain rising segments (David 2026-07-17: smooth
    // ascent, no staircase); carry samples keep the flat tail to today.
    return sorted.enumerated().map { index, point in
      let x = sorted.count == 1 ? width / 2 : Double(index) * width / Double(sorted.count - 1)
      let normalized = (point.e1RMKg - minValue) / span
      return CGPoint(x: x, y: top + (1 - normalized) * usableHeight)
    }
  }
}
