import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No cache by design (spec 032 §9): archive edits must read back
/// consistently; the wizard's offline resilience is LocalOnboardingDraftStore,
/// not a stale profile copy.
public actor BackendOnboardingRepository: OnboardingRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    let token = try await session.accessToken()
    do {
      return try await api.onboardingProfile(studentId: studentId, accessToken: token)
        .toDomain()
    } catch {
      // "Never filled in" is a normal state, not an error (spec 032 D10).
      if case .notFound = Self.mappedOnboardingError(error) {
        return nil
      }
      throw error
    }
  }

  public func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    let token = try await session.accessToken()
    do {
      return try await api.upsertOnboarding(OnboardingPatchDTO(patch), accessToken: token)
        .toDomain()
    } catch {
      throw Self.mappedOnboardingError(error) ?? error
    }
  }

  public func complete() async throws -> OnboardingProfile {
    let token = try await session.accessToken()
    do {
      return try await api.completeOnboarding(accessToken: token).toDomain()
    } catch {
      throw Self.mappedOnboardingError(error) ?? error
    }
  }

  private static func mappedOnboardingError(_ error: any Error) -> OnboardingError? {
    OnboardingError(
      machineCode: BackendErrorEnvelope.machineCode(from: error),
      missingFields: BackendErrorEnvelope.missingFields(from: error)
    )
  }
}
