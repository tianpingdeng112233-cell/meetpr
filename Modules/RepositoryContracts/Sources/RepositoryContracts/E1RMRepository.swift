import CoreModels
import Foundation

/// Local-first store for e1RM history and PR breakthrough events (spec 028).
/// V0.1 keeps this entirely on-device (backend uninvolved); a Backend
/// implementation arrives with the cross-device-history spec.
public protocol E1RMRepository: Sendable {
  func recordPoint(_ point: E1RMHistoryPoint) async throws
  func fetchHistory(studentId: UUID, exerciseId: UUID) async throws -> [E1RMHistoryPoint]
  func fetchHistory(studentId: UUID, exerciseIds: [UUID]) async throws -> [UUID:
    [E1RMHistoryPoint]]
  /// Maximum e1RM over prior `.normal` points strictly before `before`.
  /// Quarantined points must never raise the PR-detection baseline.
  func maxBefore(studentId: UUID, exerciseId: UUID, before: Date) async throws -> Double?

  func recordPR(_ event: PRBreakthroughEvent) async throws
  func unacknowledgedPRs(studentId: UUID) async throws -> [PRBreakthroughEvent]
  func acknowledgePR(eventId: UUID) async throws
}
