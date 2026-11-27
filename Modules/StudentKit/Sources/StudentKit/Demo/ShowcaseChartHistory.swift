import CoreModels
import Foundation

/// Only the opt-in student scene creates logs for this reserved fixture identity.
public enum ShowcaseChartHistory {
  public static let studentID = UUID(
    uuid: (0x27, 0x11, 0x26, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 1))
}

extension GrowthScreenPresentation {
  /// The progress page requests its display window with just the two log collections.
  /// Keep its usual window for other accounts and explicit calendar/range queries.
  static func chartBuckets(logs: [StudentSetLog], added: [StudentAddedSetLog])
    -> [WeeklyProgressMetric]
  {
    if logs.first?.studentID == ShowcaseChartHistory.studentID,
      ProcessInfo.processInfo.arguments.contains("-demo-showcase")
    {
      return chartBuckets(logs: logs, added: added, calendar: .current, maximumCount: 7)
    }
    return chartBuckets(logs: logs, added: added, calendar: .current)
  }
}
