import CoreModels
import Foundation
import Networking
import RepositoryContracts

public actor BackendStudentTrainingLogRepository: StudentTrainingLogRepository {
  private let api: APIClient
  private let session: any SessionStateReader
  private let cache: TrainingLogCache

  public init(
    api: APIClient,
    session: any SessionStateReader,
    cache: TrainingLogCache = TrainingLogCache()
  ) {
    self.api = api
    self.session = session
    self.cache = cache
  }

  @discardableResult
  public func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    let token = try await session.accessToken()
    let response = try await api.logSet(
      CreateSetLogRequestDTO(
        planExerciseID: log.planExerciseID,
        setIndex: log.setIndex,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed
      ),
      accessToken: token
    )
    // The backend upserts by slot and owns the canonical id — everything
    // downstream (video set_log_id, e1RM points) must reference it.
    return StudentSetLog(
      id: response.id,
      studentID: log.studentID,
      planExerciseID: log.planExerciseID,
      setIndex: log.setIndex,
      loggedAt: response.loggedAt,
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: log.rpe,
      completed: log.completed,
      failed: log.failed,
      // A student edit is an observed log. The backend also enforces this on
      // upsert so it replaces any earlier imported assumed completion.
      assumed: false
    )
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    let from = WireFormatting.dateOnlyString(from: dateRange.lowerBound)
    let endDate = WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: dateRange.upperBound)
    let token = try await session.accessToken()

    do {
      let response = try await api.studentSetLogs(
        studentID: studentID,
        from: from,
        endDate: endDate,
        accessToken: token
      )
      let logs = response.logs.map { $0.toDomain() }.sorted { $0.loggedAt < $1.loggedAt }
      try await cache.save(logs: logs, studentID: studentID, from: from, endDate: endDate)
      return logs
    } catch {
      if let cached = await cache.loadLogs(studentID: studentID, from: from, endDate: endDate) {
        return cached
      }
      throw error
    }
  }

  public func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    let now = Date()
    let from = calendar.date(byAdding: .year, value: -5, to: now) ?? now
    let logs = try await fetchLogs(studentID: studentID, in: from...now)
    return
      logs
      .filter { $0.planExerciseID == planExerciseID }
      .sorted { $0.setIndex < $1.setIndex }
  }
}
