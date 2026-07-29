import CoreModels
import Foundation

/// Local-first store for e1RM history and PR breakthrough events (spec 028).
/// V0.1 keeps this entirely on-device (backend uninvolved); a Backend
/// implementation arrives with the cross-device-history spec.
public protocol E1RMRepository: Sendable {
  func recordPoint(_ point: E1RMHistoryPoint) async throws
  /// Replaces the point for `(studentId, setLogId)` when one exists, preserving
  /// its point ID; otherwise inserts it.
  @discardableResult
  func upsertPoint(_ point: E1RMHistoryPoint) async throws -> E1RMHistoryPoint
  /// Rewrites confidence only for imported points in the specified batch.
  func updatePointConfidence(
    studentId: UUID,
    pointIDs: Set<UUID>,
    confidence: E1RMConfidence
  ) async throws
  /// Atomically replaces one student's points, measured-weight baselines, and
  /// PR events. Other students sharing the device are retained.
  func replaceHistory(
    studentId: UUID,
    with points: [E1RMHistoryPoint],
    weightBaselines: [E1RMWeightBaseline],
    prEvents: [PRBreakthroughEvent]
  ) async throws
  func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint]
  func fetchHistory(studentId: UUID, exerciseIds: [UUID]) async throws -> [UUID:
    [E1RMHistoryPoint]]
  /// All points for one student's resolved competition family, across every
  /// catalog exercise and plan cycle.
  func fetchHistory(studentId: UUID, family: LiftFamily) async throws -> [E1RMHistoryPoint]
  /// Maximum e1RM over prior `.normal` points strictly before `before`.
  /// Quarantined points must never raise the PR-detection baseline. When an
  /// imported point is being replaced by its real log, it can be excluded by
  /// set-log identity; a logged point with that identity still participates.
  func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date,
    excludingSetLogId: UUID?
  ) async throws -> Double?

  /// Atomically keeps `candidate` only when it is strictly heavier than the
  /// stored baseline for its student and family, and returns the prior record.
  @discardableResult
  func recordWeightBaseline(
    _ candidate: E1RMWeightBaseline
  ) async throws -> E1RMWeightBaseline?
  func fetchWeightBaseline(
    studentId: UUID,
    family: LiftFamily
  ) async throws -> E1RMWeightBaseline?
  func fetchWeightBaselines(studentId: UUID) async throws -> [E1RMWeightBaseline]

  func recordPR(_ event: PRBreakthroughEvent) async throws
  /// All measured-weight PR events for one resolved competition family,
  /// including acknowledged events that still establish the rolling baseline.
  func fetchPRs(studentId: UUID, family: LiftFamily) async throws -> [PRBreakthroughEvent]
  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent]
  func acknowledgePR(eventId: UUID) async throws

  /// PR events that occurred at or after `since`, regardless of
  /// acknowledgement. Weekly-summary counters use this window query; the
  /// acknowledgement chain is dormant while no surface consumes it
  /// (celebration banner removed 2026-07-28).
  func prEvents(studentId: UUID, since: Date) async throws -> [PRBreakthroughEvent]
}

extension E1RMRepository {
  public func maxBefore(
    studentId: UUID,
    exerciseId: UUID,
    before: Date
  ) async throws -> Double? {
    try await maxBefore(
      studentId: studentId,
      exerciseId: exerciseId,
      before: before,
      excludingSetLogId: nil
    )
  }
}
