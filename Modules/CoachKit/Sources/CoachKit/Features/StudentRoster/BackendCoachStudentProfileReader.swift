import CoreModels
import Foundation
import Networking
import RepositoryContracts

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
