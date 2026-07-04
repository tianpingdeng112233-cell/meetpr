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
    guard log.planExerciseID != nil else {
      throw StudentTrainingLogRepositoryError.missingPlanLink
    }
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
        exerciseID: log.exerciseID,
        loggedDate: log.loggedDate,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed
      )
      logs[index] = persisted
    } else {
      persisted = log
      logs.append(persisted)
    }
    logsByStudentID[log.studentID] = logs.sorted { $0.loggedAt < $1.loggedAt }
    return persisted
  }

  @discardableResult
  public func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    guard let exerciseID = log.exerciseID, let loggedDate = log.loggedDate else {
      throw StudentTrainingLogRepositoryError.missingExerciseIdentity
    }
    var logs = logsByStudentID[log.studentID, default: []]
    let persisted: StudentSetLog
    if let index = logs.firstIndex(where: {
      $0.adhoc
        && $0.exerciseID == exerciseID
        && $0.loggedDate == loggedDate
        && $0.setIndex == log.setIndex
    }) {
      // Same adhoc key keeps its identity, like the backend upsert (spec 010).
      persisted = StudentSetLog(
        id: logs[index].id,
        studentID: log.studentID,
        planExerciseID: nil,
        exerciseID: exerciseID,
        loggedDate: loggedDate,
        adhoc: true,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed
      )
      logs[index] = persisted
    } else {
      persisted = StudentSetLog(
        id: log.id,
        studentID: log.studentID,
        planExerciseID: nil,
        exerciseID: exerciseID,
        loggedDate: loggedDate,
        adhoc: true,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        completed: log.completed,
        failed: log.failed
      )
      logs.append(persisted)
    }
    logsByStudentID[log.studentID] = logs.sorted { $0.loggedAt < $1.loggedAt }
    return persisted
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
    let logs = logsByStudentID[studentID, default: []]
    switch scope {
    case .plan:
      // Pre-spec-045 visible set: plan-linked rows on logged_at windows.
      return
        logs
        .filter { $0.planExerciseID != nil && dateRange.contains($0.loggedAt) }
        .sorted { $0.loggedAt < $1.loggedAt }
    case .all:
      // Training-day semantics: every row, windowed on the client-local
      // logged date (mirrors backend spec 010's scope=all).
      let fromDay = Self.dayString(dateRange.lowerBound)
      let toDay = Self.dayString(dateRange.upperBound)
      return
        logs
        .filter { log in
          let day = log.loggedDate ?? Self.dayString(log.loggedAt)
          return day >= fromDay && day <= toDay
        }
        .sorted { $0.loggedAt < $1.loggedAt }
    }
  }

  public func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    logsByStudentID[studentID, default: []]
      .filter { $0.planExerciseID == planExerciseID }
      .sorted { $0.setIndex < $1.setIndex }
  }

  private static func dayString(_ date: Date) -> String {
    date.formatted(.iso8601.year().month().day())
  }
}
