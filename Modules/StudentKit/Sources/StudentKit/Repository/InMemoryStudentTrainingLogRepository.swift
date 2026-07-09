import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentTrainingLogRepository: StudentTrainingLogRepository {
  private var logsByStudentID: [UUID: [StudentSetLog]]

  public init(seed: [StudentSetLog] = []) {
    self.logsByStudentID = Dictionary(grouping: seed, by: \.studentID)
  }

  @discardableResult
  public func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    var logs = logsByStudentID[log.studentID, default: []]
    let persisted: StudentSetLog
    if let index = logs.firstIndex(where: {
      $0.studentID == log.studentID
        && $0.planExerciseID == log.planExerciseID
        && $0.setIndex == log.setIndex
    }) {
      // Same slot keeps its identity across overwrites, like the backend upsert.
      persisted = StudentSetLog(
        id: logs[index].id,
        studentID: log.studentID,
        planExerciseID: log.planExerciseID,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed,
        assumed: false
      )
      logs[index] = persisted
    } else {
      persisted = log
      logs.append(persisted)
    }
    logsByStudentID[log.studentID] = logs.sorted { $0.loggedAt < $1.loggedAt }
    return persisted
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
