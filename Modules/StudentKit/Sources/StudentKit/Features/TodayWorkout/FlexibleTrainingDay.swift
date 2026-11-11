import CoreModels
import Foundation

/// Sequence editability is independent of recommended calendar dates.
enum FlexibleTrainingDay {
  private static let completionUndoWindow: TimeInterval = 7 * 24 * 3600

  static func canWrite(_ day: StudentPlanDay, in days: [StudentPlanDay]) -> Bool {
    day.completedAt == nil
      && days.contains { $0.id == day.id && $0.completedAt == nil }
  }

  static func canUndo(_ dayID: UUID, days: [StudentPlanDay], now: Date) -> Bool {
    let latest = days.filter { $0.completedAt != nil }.max {
      ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
    }
    guard latest?.id == dayID, let date = latest?.completedAt else { return false }
    return now.timeIntervalSince(date) < completionUndoWindow
  }
}
