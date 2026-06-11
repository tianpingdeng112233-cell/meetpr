import CoreModels
import Foundation

/// Typed mirror of the backend evaluation machine codes (spec 033 §6).
public enum EvaluationError: Error, Equatable, Sendable {
  /// 404 EVALUATION_NOT_FOUND — fetches translate it to nil instead; only
  /// `completeEvaluation` surfaces it (the period vanished mid-flow).
  case notFound
  /// 409 EVALUATION_ALREADY_COMPLETED — concurrent complete; callers treat
  /// it as success and refresh (spec 033 §6/§8).
  case alreadyCompleted
}

extension EvaluationError {
  /// nil means "not an evaluation code — rethrow the original error".
  public init?(machineCode: String?) {
    switch machineCode {
    case "EVALUATION_NOT_FOUND": self = .notFound
    case "EVALUATION_ALREADY_COMPLETED": self = .alreadyCompleted
    default: return nil
    }
  }
}

/// Evaluation periods, both perspectives (spec 033 §6/§11). Coach-side
/// implementations serve `fetchEvaluation`; student-side ones serve
/// `fetchMyEvaluation`; authorization is the server's (requireRole), not the
/// client's. No cache by design: countdown / completion must be live.
public protocol EvaluationRepository: Sendable {
  /// GET /coach/students/:id/evaluation — latest period for (me, student),
  /// completed included. 404 → nil ("never had one" is a normal state).
  func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod?
  /// GET /students/me/evaluation — latest period for the current student.
  /// 404 → nil.
  func fetchMyEvaluation() async throws -> EvaluationPeriod?
  /// POST /coach/evaluations/:id/complete. Throws
  /// `EvaluationError.alreadyCompleted` on the concurrent-complete 409.
  func completeEvaluation(id: UUID) async throws -> EvaluationPeriod
}

/// Evaluation summaries (spec 033 §8/§12). PUT is coach-only (server gate);
/// fetch serves self or the authoring coach. No cache by design.
public protocol EvaluationSummaryRepository: Sendable {
  /// GET /students/:id/evaluation-summary. 404 → nil ("not written yet").
  func fetchSummary(studentID: UUID) async throws -> EvaluationSummary?
  /// PUT /coach/students/:id/evaluation-summary — upsert + version snapshot.
  /// `notifyStudent` is booked server-side only; the student-side unread
  /// state is local (spec 033 D7).
  func putSummary(
    studentID: UUID,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) async throws -> EvaluationSummary
}
