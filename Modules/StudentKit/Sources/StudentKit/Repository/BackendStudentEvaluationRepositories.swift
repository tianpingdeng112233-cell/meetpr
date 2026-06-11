import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// Student-side evaluation periods (spec 033 §11). No cache by design: the
/// BindGate must see completion live.
public actor BackendStudentEvaluationRepository: EvaluationRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
    // Coach-perspective endpoint; unused by StudentKit UI. The server's
    // requireRole gate answers a student token anyway.
    let token = try await session.accessToken()
    do {
      return try await api.coachStudentEvaluation(studentId: studentID, accessToken: token)
        .toDomain()
    } catch {
      if case .notFound = Self.mappedEvaluationError(error) {
        return nil
      }
      throw error
    }
  }

  public func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    let token = try await session.accessToken()
    do {
      return try await api.myEvaluation(accessToken: token).toDomain()
    } catch {
      if case .notFound = Self.mappedEvaluationError(error) {
        return nil
      }
      throw error
    }
  }

  public func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    // Coach-only endpoint (server gate); protocol completeness.
    let token = try await session.accessToken()
    do {
      return try await api.completeEvaluation(id: id, accessToken: token).toDomain()
    } catch {
      throw Self.mappedEvaluationError(error) ?? error
    }
  }

  private static func mappedEvaluationError(_ error: any Error) -> EvaluationError? {
    EvaluationError(machineCode: BackendErrorEnvelope.machineCode(from: error))
  }
}

/// Student-side evaluation summaries (spec 033 §12). No cache by design.
public actor BackendEvaluationSummaryRepository: EvaluationSummaryRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchSummary(studentID: UUID) async throws -> EvaluationSummary? {
    let token = try await session.accessToken()
    do {
      return try await api.evaluationSummary(studentId: studentID, accessToken: token).toDomain()
    } catch {
      if BackendErrorEnvelope.machineCode(from: error) == "EVALUATION_SUMMARY_NOT_FOUND" {
        return nil
      }
      throw error
    }
  }

  public func putSummary(
    studentID: UUID,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) async throws -> EvaluationSummary {
    // Coach-only write (server gate); protocol completeness.
    let token = try await session.accessToken()
    return try await api.putEvaluationSummary(
      studentId: studentID,
      PutEvaluationSummaryRequestDTO(
        overallAssessment: overallAssessment,
        trainingPlan: trainingPlan,
        wordsToStudent: wordsToStudent,
        notifyStudent: notifyStudent
      ),
      accessToken: token
    ).toDomain()
  }
}
