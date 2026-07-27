import Foundation

public enum CoachSignalType: String, Codable, Equatable, Sendable {
  case missedTraining = "missed_training"
  case weightFailed = "weight_failed"
  case personalRecord = "pr_congrats"
}

public enum CoachSignalSeverity: String, Codable, Equatable, Sendable {
  case red
  case yellow
  case green
}

public struct CoachSignal: Equatable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let studentName: String
  public let type: CoachSignalType
  public let severity: CoachSignalSeverity
  public let reason: String
  public let openedAt: Date

  public init(
    id: UUID,
    studentID: UUID,
    studentName: String,
    type: CoachSignalType,
    severity: CoachSignalSeverity,
    reason: String,
    openedAt: Date
  ) {
    self.id = id
    self.studentID = studentID
    self.studentName = studentName
    self.type = type
    self.severity = severity
    self.reason = reason
    self.openedAt = openedAt
  }
}

/// Read model for the coach's Today discovery layer.
public protocol CoachDashboardRepository: Sendable {
  func fetchOpenSignals() async throws -> [CoachSignal]

  /// Returns display-ready backend copy. A null body or read failure is gated
  /// here as nil so views never own transport error handling for the digest.
  func fetchDailyDigestBody() async -> String?
}
