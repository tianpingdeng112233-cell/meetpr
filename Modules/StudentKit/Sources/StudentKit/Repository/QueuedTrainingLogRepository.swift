import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// A pending adhoc write: exactly the identity and values needed to replay it.
public struct PendingAdhocSetLog: Codable, Equatable, Sendable {
  public let studentID: UUID
  public let exerciseID: UUID
  public let loggedDate: String
  public let setIndex: Int
  public let weightKg: Decimal
  public let reps: Int
  public let rpe: Decimal?
  public let completed: Bool
  public let failed: Bool
  public let queuedAt: Date

  public init(log: StudentSetLog, exerciseID: UUID, loggedDate: String, queuedAt: Date) {
    self.studentID = log.studentID
    self.exerciseID = exerciseID
    self.loggedDate = loggedDate
    self.setIndex = log.setIndex
    self.weightKg = log.weightKg
    self.reps = log.reps
    self.rpe = log.rpe
    self.completed = log.completed
    self.failed = log.failed
    self.queuedAt = queuedAt
  }

  func toLog(loggedAt: Date) -> StudentSetLog {
    StudentSetLog(
      id: UUID(),
      studentID: studentID,
      planExerciseID: nil,
      exerciseID: exerciseID,
      loggedDate: loggedDate,
      adhoc: true,
      setIndex: setIndex,
      loggedAt: loggedAt,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      completed: completed,
      failed: failed
    )
  }
}

/// Disk-backed FIFO of adhoc writes that failed on transport. One small JSON
/// array per student under Application Support; volumes are a gym session's
/// worth of sets, so whole-file rewrites are fine.
public actor PendingSetLogStore {
  private let directory: URL

  public init(directory: URL? = nil) {
    if let directory {
      self.directory = directory
    } else {
      let base =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
      self.directory = base.appendingPathComponent("PendingSetLogs", isDirectory: true)
    }
  }

  public func all(studentID: UUID) -> [PendingAdhocSetLog] {
    guard let data = try? Data(contentsOf: fileURL(studentID: studentID)) else { return [] }
    return (try? JSONDecoder().decode([PendingAdhocSetLog].self, from: data)) ?? []
  }

  public func count(studentID: UUID) -> Int {
    all(studentID: studentID).count
  }

  public func append(_ pending: PendingAdhocSetLog) throws {
    var rows = all(studentID: pending.studentID)
    // Same adhoc key replaces in place — mirrors the server upsert so a
    // re-edited offline set replays once with its final values.
    if let index = rows.firstIndex(where: {
      $0.exerciseID == pending.exerciseID
        && $0.loggedDate == pending.loggedDate
        && $0.setIndex == pending.setIndex
    }) {
      rows[index] = pending
    } else {
      rows.append(pending)
    }
    try replace(studentID: pending.studentID, with: rows)
  }

  public func replace(studentID: UUID, with rows: [PendingAdhocSetLog]) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(rows)
    try data.write(to: fileURL(studentID: studentID), options: .atomic)
  }

  private func fileURL(studentID: UUID) -> URL {
    directory.appendingPathComponent("pending-\(studentID.uuidString).json")
  }
}

/// Write-resilience decorator (spec 045 「断网不丢」): adhoc writes that fail
/// on transport are persisted and replayed FIFO before the next write/fetch.
/// Complements TrainingLogCache, which covers offline *reads*.
public actor QueuedTrainingLogRepository: StudentTrainingLogRepository {
  private let upstream: any StudentTrainingLogRepository
  private let store: PendingSetLogStore
  private let now: @Sendable () -> Date

  public init(
    upstream: any StudentTrainingLogRepository,
    store: PendingSetLogStore,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.upstream = upstream
    self.store = store
    self.now = now
  }

  @discardableResult
  public func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    // Coached writes pass through untouched (queueing them is out of spec 045).
    try await upstream.recordSet(log)
  }

  @discardableResult
  public func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    guard let exerciseID = log.exerciseID, let loggedDate = log.loggedDate else {
      throw StudentTrainingLogRepositoryError.missingExerciseIdentity
    }
    // Older pending rows replay first so the server sees writes in order.
    try? await flush(studentID: log.studentID)
    do {
      return try await upstream.recordAdhocSet(log)
    } catch {
      guard Self.isQueueable(error) else { throw error }
      try await store.append(
        PendingAdhocSetLog(
          log: log, exerciseID: exerciseID, loggedDate: loggedDate, queuedAt: now())
      )
      // Optimistic local echo; the caller can surface "未同步" via pendingCount.
      return log
    }
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    try await upstream.fetchLogs(studentID: studentID, in: dateRange)
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>,
    scope: TrainingLogScope
  ) async throws -> [StudentSetLog] {
    try? await flush(studentID: studentID)
    return try await upstream.fetchLogs(studentID: studentID, in: dateRange, scope: scope)
  }

  public func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    try await upstream.fetchLogsForExercise(studentID: studentID, planExerciseID: planExerciseID)
  }

  public func pendingCount(studentID: UUID) async -> Int {
    await store.count(studentID: studentID)
  }

  /// Replays pending rows FIFO. Stops (keeping the remainder) on a transport
  /// failure; drops rows the server rejects outright (4xx) — keeping them
  /// would wedge the queue forever behind a poisoned write.
  public func flush(studentID: UUID) async throws {
    var rows = await store.all(studentID: studentID)
    guard !rows.isEmpty else { return }

    while let next = rows.first {
      do {
        _ = try await upstream.recordAdhocSet(next.toLog(loggedAt: now()))
        rows.removeFirst()
      } catch {
        if Self.isQueueable(error) {
          try await store.replace(studentID: studentID, with: rows)
          throw error
        }
        rows.removeFirst()
      }
    }
    try await store.replace(studentID: studentID, with: rows)
  }

  /// Transport-level and server-side (5xx) failures are retriable; 4xx
  /// validation outcomes are not.
  static func isQueueable(_ error: Error) -> Bool {
    if error is URLError { return true }
    if let apiError = error as? APIError {
      switch apiError {
      case .httpStatus(let code, _): return code >= 500
      case .invalidResponse: return true
      case .authInvalid: return false
      }
    }
    if let clientError = error as? APIClientError {
      switch clientError {
      case .httpStatus(let code, _): return code >= 500
      case .invalidResponse: return true
      }
    }
    return false
  }
}
