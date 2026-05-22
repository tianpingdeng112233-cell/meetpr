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

actor FailingTrainingLogRepository: StudentTrainingLogRepository {
  func recordSet(_ log: StudentSetLog) async throws {
    throw TestError()
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    []
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}
