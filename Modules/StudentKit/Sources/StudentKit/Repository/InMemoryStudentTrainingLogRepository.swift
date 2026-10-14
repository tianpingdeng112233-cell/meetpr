import CoreModels
import Foundation
import RepositoryContracts

public actor InMemoryStudentTrainingLogRepository: StudentTrainingLogRepository {
  private var addedLogs: [StudentAddedSetLog]
  private var logsByStudentID: [UUID: [StudentSetLog]]

  public init(seed: [StudentSetLog] = [], added: [StudentAddedSetLog] = []) {
    self.addedLogs = added
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
        exerciseID: log.exerciseID,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        loggedDate: log.loggedDate,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        coachRPE: log.coachRPE,
        completed: log.completed,
        failed: log.failed,
        assumed: false
      )
      logs[index] = persisted
    } else {
      persisted = StudentSetLog(
        id: log.id,
        studentID: log.studentID,
        planExerciseID: log.planExerciseID,
        exerciseID: log.exerciseID,
        setIndex: log.setIndex,
        loggedAt: log.loggedAt,
        loggedDate: log.loggedDate,
        weightKg: log.weightKg,
        reps: log.reps,
        rpe: log.rpe,
        coachRPE: log.coachRPE,
        completed: log.completed,
        failed: log.failed,
        assumed: false
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

extension InMemoryStudentTrainingLogRepository: StudentAddedLogRepository {
  public func fetchAllLogs(
    studentID: UUID, in range: ClosedRange<Date>
  ) async throws -> StudentWorkoutLogs {
    StudentWorkoutLogs(
      planned: try await fetchLogs(studentID: studentID, in: range),
      added: addedLogs.filter { $0.studentID == studentID && range.contains($0.loggedAt) })
  }

  public func recordAddedSet(_ log: StudentAddedSetLog) async throws -> StudentAddedSetLog {
    if let previous = addedLogs.first(where: {
      $0.studentID == log.studentID && $0.exerciseID == log.exerciseID
        && $0.loggedDate == log.loggedDate
    }), previous.planDayID != log.planDayID {
      throw StudentAddedLogError.dayConflict
    }
    let index = addedLogs.firstIndex {
      $0.studentID == log.studentID && $0.exerciseID == log.exerciseID
        && $0.loggedDate == log.loggedDate && $0.setIndex == log.setIndex
    }
    let saved = StudentAddedSetLog(
      id: index.map { addedLogs[$0].id } ?? log.id, studentID: log.studentID,
      planDayID: log.planDayID, exerciseID: log.exerciseID, setIndex: log.setIndex,
      loggedAt: log.loggedAt, loggedDate: log.loggedDate, weightKg: log.weightKg,
      reps: log.reps, rpe: log.rpe, completed: log.completed, failed: log.failed)
    if let index { addedLogs[index] = saved } else { addedLogs.append(saved) }
    return saved
  }

  public func deleteAddedSet(id: UUID, studentID: UUID) async throws {
    if addedLogs.contains(where: { $0.id == id && $0.studentID == studentID && $0.coachRPE != nil })
      || logsByStudentID[studentID, default: []].contains(where: {
        $0.id == id && $0.coachRPE != nil
      })
    {
      throw StudentAddedLogError.coachFeedback
    }
    addedLogs.removeAll { $0.id == id && $0.studentID == studentID }
    logsByStudentID[studentID]?.removeAll { $0.id == id }
  }
}
