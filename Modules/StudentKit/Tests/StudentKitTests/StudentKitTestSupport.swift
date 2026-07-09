import CoreModels
import Foundation
import RepositoryContracts

actor TestStudentPlanStore: StudentPlanStore {
  private var projections: [UUID: StudentPlanView] = [:]

  init(seed: [UUID: StudentPlanView] = [:]) {
    self.projections = seed
  }

  func savePublishedProjection(_ projection: StudentPlanView, forStudent studentID: UUID) async {
    projections[studentID] = projection
  }

  func getPublishedProjection(forStudent studentID: UUID) async -> StudentPlanView? {
    projections[studentID]
  }
}

struct TestError: Error, Equatable {}

/// A plan repository whose every read throws a caller-supplied error. Used to
/// drive a view model's `catch` branch — e.g. to assert that a cancelled
/// `.task` (URLError.cancelled / CancellationError) is not surfaced as a load
/// failure.
struct ThrowingStudentPlanRepository: StudentPlanRepository {
  let makeError: @Sendable () -> any Error

  init(_ makeError: @escaping @Sendable () -> any Error) {
    self.makeError = makeError
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { throw makeError() }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { throw makeError() }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { throw makeError() }
}

/// A training-log repository whose `recordSet` throws a caller-supplied error.
/// Used to drive the set-logging `catch` — e.g. to assert a cancelled
/// recordSet restores the prior `.loaded` workout instead of stranding `.recording`.
actor ThrowingTrainingLogRepository: StudentTrainingLogRepository {
  private let makeError: @Sendable () -> any Error

  init(_ makeError: @escaping @Sendable () -> any Error) {
    self.makeError = makeError
  }

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw makeError()
  }

  @discardableResult
  func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw makeError()
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>,
    scope: TrainingLogScope
  ) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

actor FailingTrainingLogRepository: StudentTrainingLogRepository {
  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw TestError()
  }

  @discardableResult
  func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    throw TestError()
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>,
    scope: TrainingLogScope
  ) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}
