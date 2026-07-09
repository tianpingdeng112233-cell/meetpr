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
    // This is the coached write path: a set recorded against a plan slot.
    // Adhoc sets (no plan link) go through the spec-045 adhoc path instead.
    guard let planExerciseID = log.planExerciseID else {
      throw StudentTrainingLogRepositoryError.missingPlanLink
    }
    let token = try await session.accessToken()
    let response = try await api.logSet(
      CreateSetLogRequestDTO(
        planExerciseID: planExerciseID,
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
      planExerciseID: planExerciseID,
      assumed: false,
      setIndex: log.setIndex,
      loggedAt: response.loggedAt,
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: log.rpe,
      completed: log.completed,
      failed: log.failed
    )
  }

  @discardableResult
  public func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    guard let exerciseID = log.exerciseID, let loggedDate = log.loggedDate else {
      throw StudentTrainingLogRepositoryError.missingExerciseIdentity
    }
    let token = try await session.accessToken()
    let response = try await api.logAdhocSet(
      CreateAdhocSetLogRequestDTO(
        exerciseID: exerciseID,
        loggedDate: loggedDate,
        setIndex: log.setIndex,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed
      ),
      accessToken: token
    )
    return StudentSetLog(
      id: response.id,
      studentID: log.studentID,
      planExerciseID: nil,
      exerciseID: exerciseID,
      loggedDate: loggedDate,
      adhoc: true,
      assumed: false,
      setIndex: log.setIndex,
      loggedAt: response.loggedAt,
      weightKg: log.weightKg,
      reps: log.reps,
      rpe: log.rpe,
      completed: log.completed,
      failed: log.failed
    )
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    try await fetchLogs(studentID: studentID, in: dateRange, scope: .plan)
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>,
    scope: TrainingLogScope
  ) async throws -> [StudentSetLog] {
    let from = WireFormatting.dateOnlyString(from: dateRange.lowerBound)
    let endDate = WireFormatting.exclusiveEndDateOnlyString(closedUpperBound: dateRange.upperBound)
    let token = try await session.accessToken()
    // .plan omits the query param — byte-for-byte the pre-spec-045 request,
    // and the server default matches (backend spec 010).
    let wireScope: SetLogFetchScope? = scope == .all ? .all : nil

    do {
      let response = try await api.studentSetLogs(
        studentID: studentID,
        from: from,
        endDate: endDate,
        scope: wireScope,
        accessToken: token
      )
      let logs = response.logs.map { $0.toDomain() }.sorted { $0.loggedAt < $1.loggedAt }
      try await cache.save(
        logs: logs, studentID: studentID, from: from, endDate: endDate, scope: scope.rawValue)
      return logs
    } catch {
      if let cached = await cache.loadLogs(
        studentID: studentID, from: from, endDate: endDate, scope: scope.rawValue)
      {
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
