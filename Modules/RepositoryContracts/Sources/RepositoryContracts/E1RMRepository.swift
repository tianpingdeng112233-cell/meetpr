import CoreModels
import Foundation

/// Local-first store for e1RM history and PR breakthrough events (spec 028).
/// V0.1 keeps this entirely on-device (backend uninvolved); a Backend
/// implementation arrives with the cross-device-history spec.
public protocol E1RMRepository: Sendable {
  /// Appends an independently-recorded point. New consumers that need stable
  /// set-log identity should use `upsertPoint(_:)` instead.
  func recordPoint(_ point: E1RMHistoryPoint) async throws
  /// Replaces the point for `(studentId, setLogId)` when one exists, preserving
  /// its point ID; otherwise inserts it. This makes imported-history replay
  /// idempotent and lets a real set overwrite its earlier assumed counterpart.
  @discardableResult
  func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint
  /// Rewrites the confidence of a specific reviewed batch without touching
  /// older batches from the same lift family (spec 053 §5).
  func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws
  /// Replaces one student's local history and clears their stored PR events.
  /// Used by one-shot client migrations that replay canonical set logs through
  /// the recorder; other students sharing the device are kept.
  func replaceHistory(studentId: UUID, with points: [E1RMHistoryPoint]) async throws
  func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint]
  func fetchHistory(studentId: UUID, exerciseIds: [UUID]) async throws -> [UUID:
    [E1RMHistoryPoint]]
  /// Maximum e1RM over prior `.normal` points strictly before `before` — the
  /// PR-detection baseline. Quarantined `.low` points (spec 050 §5) are excluded
  /// so a mis-logged spike never becomes the bar the next real PR must clear.
  /// `excludingSetLogId` additionally drops an *imported* point being replaced
  /// by its real log (spec 053 §3); a prior logged point under the same
  /// identity still gates, so re-checking a set cannot farm duplicate PRs.
  func maxBefore(
    studentId: UUID, exerciseId: UUID, before: Date, excludingSetLogId: UUID?
  ) async throws -> Double?

  func recordPR(_ event: PRBreakthroughEvent) async throws
  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent]
  func acknowledgePR(eventId: UUID) async throws
}

extension E1RMRepository {
  /// Baseline over the full prior history with no set-log exclusion.
  public func maxBefore(studentId: UUID, exerciseId: UUID, before: Date) async throws -> Double? {
    try await maxBefore(
      studentId: studentId, exerciseId: exerciseId, before: before, excludingSetLogId: nil)
  }
}
