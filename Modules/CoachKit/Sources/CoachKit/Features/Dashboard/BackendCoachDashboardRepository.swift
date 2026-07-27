import Foundation
import Networking
import RepositoryContracts

public enum BackendCoachDashboardRepositoryError: Error, Equatable, Sendable {
  case invalidSignalType(String)
  case invalidSeverity(String)
}

public actor BackendCoachDashboardRepository: CoachDashboardRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchOpenSignals() async throws -> [CoachSignal] {
    let token = try await session.accessToken()
    return try await api.coachSignals(accessToken: token).signals.map(Self.signal(from:))
  }

  public func fetchDailyDigestBody() async -> String? {
    guard let token = try? await session.accessToken() else { return nil }
    return try? await api.coachDailyDigest(accessToken: token).body
  }

  private static func signal(from dto: CoachSignalDTO) throws -> CoachSignal {
    guard let type = CoachSignalType(rawValue: dto.signalType) else {
      throw BackendCoachDashboardRepositoryError.invalidSignalType(dto.signalType)
    }
    guard let severity = CoachSignalSeverity(rawValue: dto.severity) else {
      throw BackendCoachDashboardRepositoryError.invalidSeverity(dto.severity)
    }
    return CoachSignal(
      id: dto.id,
      studentID: dto.studentId,
      studentName: dto.studentName,
      type: type,
      severity: severity,
      reason: dto.reason,
      openedAt: dto.openedAt
    )
  }
}
