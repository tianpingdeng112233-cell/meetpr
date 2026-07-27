import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No cache by design (spec 033 §技术要求): the queue is lazily expired
/// server-side — a stale card must fail loudly through the accept/reject
/// 4xx machine codes, not linger.
public actor BackendCoachBindQueueRepository: CoachBindQueueRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchQueue() async throws -> [CoachBindRequestItem] {
    let token = try await session.accessToken()
    return try await api.coachBindRequests(accessToken: token)
      .bindRequests
      .map(Self.item(from:))
  }

  public func accept(requestID: UUID) async throws {
    let token = try await session.accessToken()
    do {
      _ = try await api.acceptBindRequest(
        id: requestID,
        AcceptBindRequestRequestDTO(),
        accessToken: token
      )
    } catch {
      throw Self.mapped(error)
    }
  }

  public func reject(requestID: UUID) async throws {
    let token = try await session.accessToken()
    do {
      _ = try await api.rejectBindRequest(id: requestID, accessToken: token)
    } catch {
      throw Self.mapped(error)
    }
  }

  private static func mapped(_ error: any Error) -> any Error {
    CoachBindQueueError(machineCode: BackendErrorEnvelope.machineCode(from: error)) ?? error
  }

  private static func item(from dto: CoachBindRequestItemDTO) -> CoachBindRequestItem {
    CoachBindRequestItem(
      id: dto.id,
      studentId: dto.studentId,
      displayName: dto.displayName,
      submittedAt: dto.submittedAt,
      expiredAt: dto.expiredAt,
      onboarding: CoachBindRequestOnboardingSummary(
        completed: dto.onboarding.completed,
        gender: dto.onboarding.gender,
        birthDate: dto.onboarding.birthDate,
        weightKg: dto.onboarding.weightKg,
        trainingYears: dto.onboarding.trainingYears,
        squat1RMKg: dto.onboarding.squat1RMKg,
        bench1RMKg: dto.onboarding.bench1RMKg,
        deadlift1RMKg: dto.onboarding.deadlift1RMKg,
        muscleGroupsToStrengthen: dto.onboarding.muscleGroupsToStrengthen,
        gymTier: dto.onboarding.gymTier,
        isCompeting: dto.onboarding.isCompeting,
        competitionDate: dto.onboarding.competitionDate,
        noteToCoach: dto.onboarding.noteToCoach,
        uploadCount: dto.onboarding.uploadCount
      )
    )
  }
}
