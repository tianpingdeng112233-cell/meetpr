import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No local cache by design (spec 030 §C3): the payload is tiny and the
/// semantics are same-day — a failed submit is a failure, not stale data.
public actor BackendReadinessRepository: ReadinessRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func submit(_ checkin: ReadinessCheckin) async throws {
    let token = try await session.accessToken()
    try await api.submitReadiness(
      SubmitReadinessRequestDTO(
        checkinDate: checkin.checkinDate,
        sleepQuality: checkin.sleepQuality,
        energy: checkin.energy,
        mood: checkin.mood,
        stress: checkin.stress,
        muscleFatigue: checkin.muscleFatigue.map {
          MuscleFatigueDTO(muscleGroup: $0.muscleGroup.rawValue, severity: $0.severity)
        }
      ),
      accessToken: token
    )
  }

  public func fetchCheckin(
    studentId: UUID,
    checkinDate: String
  ) async throws -> ReadinessCheckin? {
    let token = try await session.accessToken()
    let response = try await api.readinessCheckin(
      studentID: studentId,
      date: checkinDate,
      accessToken: token
    )
    return response.checkin?.toDomain()
  }
}
