import CoreModels
import Foundation

public enum StudentTrainingLogRepositoryError: Error, Equatable {
  /// `recordSet` was handed a log without a plan link. Coached writes
  /// require one; adhoc sets (spec 045) go through `recordAdhocSet`.
  case missingPlanLink
  /// `recordAdhocSet` was handed a log without `exerciseID`/`loggedDate` —
  /// the identity an adhoc row is keyed on.
  case missingExerciseIdentity
  /// The conformer does not support the adhoc write path (coach-side stubs).
  case adhocUnsupported
}

/// Which rows a scoped fetch returns (mirrors backend spec 010's `scope`).
public enum TrainingLogScope: String, Sendable {
  /// Plan-linked rows only — the pre-spec-045 visible set.
  case plan
  /// Plan + adhoc + orphaned rows, windowed on the client-local training day.
  case all
}

/// Records and reads back the student's actual logged sets.
public protocol StudentTrainingLogRepository: Sendable {
  /// Idempotent on `(studentID, planExerciseID, setIndex)`: re-recording overwrites.
  /// Returns the persisted log — the backend upserts by (student, exercise,
  /// set_index) and owns the canonical id, which video linkage and e1RM
  /// points must use (a locally generated id 404s on the server).
  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog
  /// Spec 045: a set born outside any plan. Requires `exerciseID` and
  /// `loggedDate` on the log; idempotent on
  /// `(studentID, exerciseID, loggedDate, setIndex)`.
  @discardableResult
  func recordAdhocSet(_ log: StudentSetLog) async throws -> StudentSetLog
  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog]
  /// Scoped variant (spec 045). `.plan` must return exactly what
  /// `fetchLogs(studentID:in:)` returns.
  func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>,
    scope: TrainingLogScope
  ) async throws -> [StudentSetLog]
  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog]
}
