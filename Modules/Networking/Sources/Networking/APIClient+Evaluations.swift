import Foundation

// Evaluation period + summary endpoints (spec 033; backend spec 005
// §endpoint C).

extension APIClient {
  /// GET /coach/students/:id/evaluation → 200; 404 EVALUATION_NOT_FOUND
  /// when the pair never had one.
  public func coachStudentEvaluation(
    studentId: UUID,
    accessToken: String
  ) async throws -> EvaluationPeriodDTO {
    try await get(
      path: "/coach/students/\(studentId.uuidString)/evaluation",
      accessToken: accessToken
    )
  }

  /// GET /students/me/evaluation → 200; 404 EVALUATION_NOT_FOUND.
  public func myEvaluation(accessToken: String) async throws -> EvaluationPeriodDTO {
    try await get(path: "/students/me/evaluation", accessToken: accessToken)
  }

  /// POST /coach/evaluations/:id/complete → 200; 409
  /// EVALUATION_ALREADY_COMPLETED on a repeat.
  public func completeEvaluation(
    id: UUID,
    accessToken: String
  ) async throws -> EvaluationPeriodDTO {
    try await post(
      path: "/coach/evaluations/\(id.uuidString)/complete",
      accessToken: accessToken
    )
  }

  /// PUT /coach/students/:id/evaluation-summary → 200 (upsert + version
  /// snapshot; requires an accepted bond).
  public func putEvaluationSummary(
    studentId: UUID,
    _ body: PutEvaluationSummaryRequestDTO,
    accessToken: String
  ) async throws -> EvaluationSummaryDTO {
    try await put(
      path: "/coach/students/\(studentId.uuidString)/evaluation-summary",
      body: body,
      accessToken: accessToken
    )
  }

  /// GET /students/:id/evaluation-summary → 200 (self → latest active;
  /// coach → only their own row); 404 EVALUATION_SUMMARY_NOT_FOUND.
  public func evaluationSummary(
    studentId: UUID,
    accessToken: String
  ) async throws -> EvaluationSummaryDTO {
    try await get(
      path: "/students/\(studentId.uuidString)/evaluation-summary",
      accessToken: accessToken
    )
  }
}
