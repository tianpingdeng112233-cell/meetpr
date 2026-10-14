import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// Coach-only read projection. The student repository remains plan-only.
struct CoachTrainingLogReader: Sendable {
  let planning: (any PlanRepository)?
  let fallback: any StudentTrainingLogRepository

  func fetch(studentID: UUID, range: ClosedRange<Date>) async throws -> [CoachSetLogDTO] {
    if let logs = try await planning?.fetchCoachLogs(studentID: studentID, in: range) {
      return logs
    }
    return try await fallback.fetchLogs(studentID: studentID, in: range).map(CoachSetLogDTO.init)
  }
}

extension CoachSetLogDTO {
  init(_ log: StudentSetLog) {
    self.init(
      id: log.id, studentID: log.studentID, planExerciseID: log.planExerciseID,
      exerciseID: log.exerciseID, setIndex: log.setIndex, weightKg: log.weightKg,
      reps: log.reps, rpe: log.rpe, coachRPE: log.coachRPE, completed: log.completed,
      failed: log.failed, assumed: log.assumed, loggedAt: log.loggedAt, loggedDate: log.loggedDate
    )
  }

  /// Existing video/feedback consumers only accept planned sets.
  var plannedLog: StudentSetLog? {
    guard let planExerciseID else { return nil }
    return StudentSetLog(
      id: id, studentID: studentID, planExerciseID: planExerciseID, exerciseID: exerciseID,
      setIndex: setIndex, loggedAt: loggedAt, loggedDate: loggedDate,
      weightKg: weightKg, reps: reps, rpe: rpe, coachRPE: coachRPE,
      completed: completed, failed: failed, assumed: assumed
    )
  }
}
