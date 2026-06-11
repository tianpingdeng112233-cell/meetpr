import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentTrainingLogRepository: StudentTrainingLogRepository {
  private var logsByStudentID: [UUID: [StudentSetLog]]

  public init(seed: [StudentSetLog] = []) {
    self.logsByStudentID = Dictionary(grouping: seed, by: \.studentID)
  }

  public func recordSet(_ log: StudentSetLog) async throws {
    var logs = logsByStudentID[log.studentID, default: []]
    if let index = logs.firstIndex(where: {
      $0.studentID == log.studentID
        && $0.planExerciseID == log.planExerciseID
        && $0.setIndex == log.setIndex
    }) {
      logs[index] = log
    } else {
      logs.append(log)
    }
    logsByStudentID[log.studentID] = logs.sorted { $0.loggedAt < $1.loggedAt }
  }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    logsByStudentID[studentID, default: []]
      .filter { dateRange.contains($0.loggedAt) }
      .sorted { $0.loggedAt < $1.loggedAt }
  }

  public func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    logsByStudentID[studentID, default: []]
      .filter { $0.planExerciseID == planExerciseID }
      .sorted { $0.setIndex < $1.setIndex }
  }
}
