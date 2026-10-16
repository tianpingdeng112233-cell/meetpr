import Foundation
import Networking
import RepositoryContracts

public enum BackendTrainingSessionRepositoryError: Error, Equatable, Sendable {
  case missingStartedSession
  case invalidStatus(String)
}

public actor BackendTrainingSessionRepository: TrainingSessionRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let calendar: Calendar
  // Keyed by "<user id>:<day>": the repository outlives login sessions, so an
  // account switch must never surface another student's cached sessions.
  private var cachedSessions: [String: TrainingSession] = [:]

  public init(
    api: APIClient,
    session: any SessionStateReader,
    calendar: Calendar = .current
  ) {
    self.api = api
    self.session = session
    self.calendar = calendar
  }

  public func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    // Same owner-atomicity rule as startSession: capture before, verify after.
    let owner = try await session.currentUser().id.uuidString
    let token = try await session.accessToken()
    let day = date.map { Self.dayString($0, calendar: calendar) }
    let response = try await api.studentSession(date: day, accessToken: token)
    guard let dto = response.session else {
      // Cache DELETION is a cache mutation too: it stays inside the same
      // owner gate, or a response fetched under a switched account could
      // erase the previous user's entries.
      let ownerAfter = try? await session.currentUser().id.uuidString
      if let day, ownerAfter == owner {
        cachedSessions["\(owner):\(day)"] = nil
      }
      return TrainingSessionSnapshot(gymDay: response.gymDay, session: nil)
    }
    let resolved = try dto.toDomain()
    let ownerAfter = try? await session.currentUser().id.uuidString
    if ownerAfter == owner {
      cachedSessions["\(owner):\(Self.dayString(resolved.startedAt, calendar: calendar))"] =
        resolved
    }
    return TrainingSessionSnapshot(gymDay: response.gymDay, session: resolved)
  }

  public func startSession() async throws -> TrainingSessionSnapshot {
    // Owner is captured BEFORE the request and re-verified AFTER: if the
    // account switches while the request is in flight, the response belongs
    // to the previous user and must not be written into the new user's cache
    // namespace (idempotent POST can return a completed session — leaking its
    // duration across accounts otherwise).
    let ownerBefore = try await session.currentUser().id.uuidString
    let token = try await session.accessToken()
    let response = try await api.startStudentSession(accessToken: token)
    guard let dto = response.session else {
      throw BackendTrainingSessionRepositoryError.missingStartedSession
    }
    let resolved = try dto.toDomain()
    let ownerAfter = try? await session.currentUser().id.uuidString
    if ownerAfter == ownerBefore {
      cachedSessions["\(ownerBefore):\(Self.dayString(resolved.startedAt, calendar: calendar))"] =
        resolved
    }
    return TrainingSessionSnapshot(gymDay: response.gymDay, session: resolved)
  }

  public func markCompleted(date: Date, duration: Int) async {
    // The backend set-log hook owns session completion. There is no separate
    // completion endpoint for the client to call.
  }

  public func recentCompletedSession(before date: Date) async -> TrainingSession? {
    guard let owner = try? await session.currentUser().id.uuidString else { return nil }
    return
      cachedSessions
      .filter { $0.key.hasPrefix("\(owner):") }
      .map(\.value)
      .filter { $0.status == .completed && $0.startedAt < date }
      .max { $0.startedAt < $1.startedAt }
  }

  private static func dayString(_ date: Date, calendar: Calendar) -> String {
    var formatStyle = Date.ISO8601FormatStyle(timeZone: calendar.timeZone)
      .year().month().day()
    formatStyle.timeZone = calendar.timeZone
    return date.formatted(formatStyle)
  }
}

public actor InMemoryTrainingSessionRepository: TrainingSessionRepository {
  private let calendar: Calendar
  private let now: @Sendable () -> Date
  private var sessionsByDay: [String: TrainingSession]

  public init(
    seed: [TrainingSession] = [],
    calendar: Calendar = .current,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.calendar = calendar
    self.now = now
    self.sessionsByDay = Dictionary(
      seed.map { (Self.dayString($0.startedAt, calendar: calendar), $0) },
      uniquingKeysWith: { _, latest in latest }
    )
  }

  public func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    let day = Self.dayString(date ?? now(), calendar: calendar)
    return TrainingSessionSnapshot(gymDay: day, session: sessionsByDay[day])
  }

  public func startSession() async throws -> TrainingSessionSnapshot {
    let startedAt = now()
    let day = Self.dayString(startedAt, calendar: calendar)
    if let existing = sessionsByDay[day] {
      return TrainingSessionSnapshot(gymDay: day, session: existing)
    }
    let created = TrainingSession(
      status: .inProgress,
      startedAt: startedAt,
      lastSetAt: startedAt,
      completedAt: nil,
      durationSeconds: 0
    )
    sessionsByDay[day] = created
    return TrainingSessionSnapshot(gymDay: day, session: created)
  }

  public func markCompleted(date: Date, duration: Int) async {
    let day = Self.dayString(date, calendar: calendar)
    guard let existing = sessionsByDay[day] else { return }
    let completedAt = existing.startedAt.addingTimeInterval(TimeInterval(max(0, duration)))
    sessionsByDay[day] = TrainingSession(
      status: .completed,
      startedAt: existing.startedAt,
      lastSetAt: completedAt,
      completedAt: completedAt,
      durationSeconds: max(0, duration)
    )
  }

  public func recentCompletedSession(before date: Date) async -> TrainingSession? {
    sessionsByDay.values
      .filter { $0.status == .completed && $0.startedAt < date }
      .max { $0.startedAt < $1.startedAt }
  }

  private static func dayString(_ date: Date, calendar: Calendar) -> String {
    var formatStyle = Date.ISO8601FormatStyle(timeZone: calendar.timeZone)
      .year().month().day()
    formatStyle.timeZone = calendar.timeZone
    return date.formatted(formatStyle)
  }
}

extension TrainingSessionDTO {
  fileprivate func toDomain() throws -> TrainingSession {
    guard let resolvedStatus = TrainingSessionStatus(rawValue: status) else {
      throw BackendTrainingSessionRepositoryError.invalidStatus(status)
    }
    return TrainingSession(
      status: resolvedStatus,
      startedAt: startedAt,
      lastSetAt: lastSetAt,
      completedAt: completedAt,
      durationSeconds: durationSeconds
    )
  }
}
