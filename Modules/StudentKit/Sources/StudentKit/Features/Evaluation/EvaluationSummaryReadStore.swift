import Foundation

/// Local read-state for the evaluation summary (spec 033 D7): V0.1b has no
/// APNs, so "unread" is a device-local timestamp compared against the wire's
/// `last_updated_at`. Losing it on a device switch only re-shows the
/// dashboard card once — acceptable.
public protocol EvaluationSummaryReadStoring: Sendable {
  func lastReadAt(studentID: UUID) -> Date?
  func markRead(studentID: UUID, at date: Date)
}

/// UserDefaults-backed store. UserDefaults is documented thread-safe, hence
/// the @unchecked Sendable.
public final class UserDefaultsEvaluationSummaryReadStore: EvaluationSummaryReadStoring,
  @unchecked Sendable
{
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func lastReadAt(studentID: UUID) -> Date? {
    defaults.object(forKey: Self.key(studentID)) as? Date
  }

  public func markRead(studentID: UUID, at date: Date) {
    defaults.set(date, forKey: Self.key(studentID))
  }

  private static func key(_ studentID: UUID) -> String {
    "meetpr.evaluation_summary.read_at.\(studentID.uuidString)"
  }
}

/// In-memory store for previews/tests.
public final class InMemoryEvaluationSummaryReadStore: EvaluationSummaryReadStoring,
  @unchecked Sendable
{
  private var readAt: [UUID: Date]
  private let lock = NSLock()

  public init(seed: [UUID: Date] = [:]) {
    readAt = seed
  }

  public func lastReadAt(studentID: UUID) -> Date? {
    lock.withLock { readAt[studentID] }
  }

  public func markRead(studentID: UUID, at date: Date) {
    lock.withLock { readAt[studentID] = date }
  }
}
