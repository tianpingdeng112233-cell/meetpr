import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// Coach-side evaluation periods (spec 033 §6). No cache by design:
/// countdown and completion state must be live.
public actor BackendCoachEvaluationRepository: EvaluationRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
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
    // Student-perspective endpoint; a coach token gets the server's role
    // gate. Implemented for protocol completeness, unused by CoachKit UI.
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

/// Coach-side evaluation summaries (spec 033 §8). No cache by design.
public actor BackendCoachEvaluationSummaryRepository: EvaluationSummaryRepository {
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

/// Coach read access to a student's onboarding profile (spec 033 §4; backend
/// D16 authorizes bonded and live-pending coaches).
public actor BackendCoachStudentProfileReader: OnboardingProfileReading {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    let token = try await session.accessToken()
    do {
      return try await api.onboardingProfile(studentId: studentId, accessToken: token).toDomain()
    } catch {
      if BackendErrorEnvelope.machineCode(from: error) == "ONBOARDING_NOT_FOUND" {
        return nil
      }
      throw error
    }
  }
}
