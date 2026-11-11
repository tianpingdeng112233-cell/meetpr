import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No cache by design (spec 032 §9): archive edits must read back
/// consistently; the wizard's offline resilience is LocalOnboardingDraftStore,
/// not a stale profile copy.
public actor BackendOnboardingRepository: OnboardingRepository, BodyWeightRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  private let now: @Sendable () -> Date
  private let timeZone: @Sendable () -> TimeZone

  public init(
    api: APIClient, session: any SessionStateReader,
    now: @escaping @Sendable () -> Date = { Date() },
    timeZone: @escaping @Sendable () -> TimeZone = { .current }
  ) {
    self.api = api
    self.session = session
    self.now = now
    self.timeZone = timeZone
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

  func fetchBodyWeights() async throws -> [BodyWeightRecord] {
    let token = try await session.accessToken()
    return try await api.bodyWeights(accessToken: token).records.map {
      BodyWeightRecord(recordedOn: $0.recordedOn, weightKg: $0.weightKg)
    }
  }

  func deleteBodyWeight(on date: String) async throws -> Decimal? {
    let token = try await session.accessToken()
    return try await api.deleteBodyWeight(on: date, accessToken: token).currentWeightKg
  }

  /// The compatibility fallback applies only to a missing new endpoint.
  func saveTodaysWeight(_ kilograms: Decimal) async throws -> Decimal? {
    let date = BodyWeightDay.string(from: now(), timeZone: timeZone())
    let token = try await session.accessToken()
    do {
      return try await api.saveBodyWeight(on: date, kilograms: kilograms, accessToken: token)
        .currentWeightKg
    } catch APIError.httpStatus(404, _) {
      var patch = OnboardingPatch()
      patch.weightKg = .value(kilograms)
      return try await upsert(patch).weightKg
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
