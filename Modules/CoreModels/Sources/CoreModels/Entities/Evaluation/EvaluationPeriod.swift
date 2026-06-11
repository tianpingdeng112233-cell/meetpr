import Foundation

/// Evaluation period for a (coach, student) pair (spec 033). Field-for-field
/// mirror of the backend evaluation_periods wire shape (backend spec 005
/// §endpoint C). `inProgress` / `overdue` are server read-time flags; display
/// math (remaining time, progress) is always recomputed from the timestamps
/// plus a local `now` — never cached (spec 033 §技术要求).
public struct EvaluationPeriod: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  public let bindRequestId: UUID
  public let startedAt: Date
  public let expectedEndAt: Date
  /// nil while the evaluation is running; the wire never auto-completes an
  /// overdue period (backend spec 005 D7).
  public let completedAt: Date?
  /// "coach_completed" today; kept as a raw string so new completion types
  /// never break decoding.
  public let completionType: String?
  public let inProgress: Bool
  public let overdue: Bool

  public init(
    id: UUID,
    studentId: UUID,
    coachId: UUID,
    bindRequestId: UUID,
    startedAt: Date,
    expectedEndAt: Date,
    completedAt: Date? = nil,
    completionType: String? = nil,
    inProgress: Bool,
    overdue: Bool
  ) {
    self.id = id
    self.studentId = studentId
    self.coachId = coachId
    self.bindRequestId = bindRequestId
    self.startedAt = startedAt
    self.expectedEndAt = expectedEndAt
    self.completedAt = completedAt
    self.completionType = completionType
    self.inProgress = inProgress
    self.overdue = overdue
  }
}

extension EvaluationPeriod {
  /// Local read-time overdue check, same rule the server applies — derived
  /// from timestamps instead of trusting a possibly stale cached flag.
  public func isOverdue(now: Date) -> Bool {
    completedAt == nil && expectedEndAt < now
  }

  /// Whole days + leftover hours until `expectedEndAt`; nil once overdue or
  /// completed. (4 days 13 hours → (4, 13).)
  public func remaining(now: Date) -> (days: Int, hours: Int)? {
    guard completedAt == nil else { return nil }
    let interval = expectedEndAt.timeIntervalSince(now)
    guard interval > 0 else { return nil }
    let totalHours = Int(interval / 3_600)
    return (days: totalHours / 24, hours: totalHours % 24)
  }

  /// Whole days + leftover hours past `expectedEndAt`; nil while still
  /// inside the window or after completion.
  public func overdueBy(now: Date) -> (days: Int, hours: Int)? {
    guard completedAt == nil else { return nil }
    let interval = now.timeIntervalSince(expectedEndAt)
    guard interval > 0 else { return nil }
    let totalHours = Int(interval / 3_600)
    return (days: totalHours / 24, hours: totalHours % 24)
  }

  /// Elapsed fraction of startedAt→expectedEndAt, clamped to 0…1 (drives the
  /// progress bars on both the coach banner and the student page).
  public func progressFraction(now: Date) -> Double {
    let span = expectedEndAt.timeIntervalSince(startedAt)
    guard span > 0 else { return 1 }
    let elapsed = now.timeIntervalSince(startedAt)
    return min(1, max(0, elapsed / span))
  }
}
