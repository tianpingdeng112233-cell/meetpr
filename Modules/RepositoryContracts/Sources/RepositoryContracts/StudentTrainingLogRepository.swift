import CoreModels
import Foundation

/// Records and reads back the student's actual logged sets.
public protocol StudentTrainingLogRepository: Sendable {
  /// Idempotent on `(studentID, planExerciseID, setIndex)`: re-recording overwrites.
  func recordSet(_ log: StudentSetLog) async throws
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog]
  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog]
}
