import CoreModels
import Foundation

/// Records and reads back the student's actual logged sets.
public protocol StudentTrainingLogRepository: Sendable {
  /// Idempotent on `(studentID, planExerciseID, setIndex)`: re-recording overwrites.
  /// Returns the persisted log — the backend upserts by (student, exercise,
  /// set_index) and owns the canonical id, which video linkage and e1RM
  /// points must use (a locally generated id 404s on the server).
  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog]
  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog]
}
