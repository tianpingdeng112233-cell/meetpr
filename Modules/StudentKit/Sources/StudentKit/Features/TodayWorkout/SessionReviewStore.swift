import Foundation

/// Remembers that the student finished the post-session review flow
/// (slide-to-complete → 训练回顾 → 完成) for a given day, so the slide control
/// does not re-arm after the summary is dismissed. Local-only, mirroring
/// `SessionReflectionStore`: the backend has no session-close concept —
/// completion is tracked per set.
public protocol SessionReviewStore: Sendable {
  func didCompleteReview(studentId: UUID, date: Date) -> Bool
  func markReviewCompleted(studentId: UUID, date: Date)
}

public struct UserDefaultsSessionReviewStore: SessionReviewStore {
  // UserDefaults is documented thread-safe but not yet Sendable-annotated;
  // the store needs to stay Sendable (it crosses into SwiftUI/actor contexts).
  nonisolated(unsafe) private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func didCompleteReview(studentId: UUID, date: Date) -> Bool {
    defaults.bool(forKey: Self.key(studentId, date))
  }

  public func markReviewCompleted(studentId: UUID, date: Date) {
    defaults.set(true, forKey: Self.key(studentId, date))
  }

  /// Same local-calendar-day key scheme as `UserDefaultsSessionReflectionStore`.
  private static func key(_ studentId: UUID, _ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    let day = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    return "session.review.\(studentId.uuidString).\(day)"
  }
}
