import Foundation

public enum TrainingSessionStatus: String, Codable, Equatable, Sendable {
  case inProgress = "in_progress"
  case completed
  case partial
}

public struct TrainingSession: Codable, Equatable, Sendable {
  public let status: TrainingSessionStatus
  public let startedAt: Date
  public let lastSetAt: Date
  public let completedAt: Date?
  public let durationSeconds: Int

  public init(
    status: TrainingSessionStatus,
    startedAt: Date,
    lastSetAt: Date,
    completedAt: Date?,
    durationSeconds: Int
  ) {
    self.status = status
    self.startedAt = startedAt
    self.lastSetAt = lastSetAt
    self.completedAt = completedAt
    self.durationSeconds = durationSeconds
  }
}

/// The backend's gym-day envelope. `gymDay` is optional while older servers
/// without backend spec 021 remain reachable.
public struct TrainingSessionSnapshot: Equatable, Sendable {
  public let gymDay: String?
  public let session: TrainingSession?

  public init(gymDay: String?, session: TrainingSession?) {
    self.gymDay = gymDay
    self.session = session
  }
}

/// Starts and restores the current student's gym-day training session.
public protocol TrainingSessionRepository: Sendable {
  /// A nil date asks the backend for its authoritative current gym-day.
  /// Explicit dates are reserved for calendar history.
  func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot
  func startSession() async throws -> TrainingSessionSnapshot
  func markCompleted(date: Date, duration: Int) async

  /// Best available completed session from the repository's local cache.
  /// Backend callers do not make an unbounded date search for this optional stat.
  func recentCompletedSession(before date: Date) async -> TrainingSession?
}
