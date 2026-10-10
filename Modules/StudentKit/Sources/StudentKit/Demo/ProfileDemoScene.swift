import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI

/// Explicit, process-only fixtures; the default demo and persisted stores are untouched.
public enum ProfileDemoScenario: String, Sendable {
  case email, phone, loading, failure, empty, unanswered
  case noCoach = "no-coach"
  case refreshFailure = "refresh-failure"
  case longIdentity = "long-identity"
  case missingLift = "missing-lift"

  public static var launchValue: Self? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-spec088-profile"),
      arguments.indices.contains(index + 1)
    else { return nil }
    return Self(rawValue: arguments[index + 1])
  }
}

public struct ProfileDemoScene: View {
  private let profile: MyProfileView

  public init(scenario: ProfileDemoScenario, onLogout: @escaping @MainActor () async -> Void) {
    let studentID = StudentDemoSeed.studentID
    let identifier =
      scenario == .phone
      ? "+15550102400"
      : scenario == .longIdentity
        ? "a.very.long.profile.identifier.for.layout@example.com"
        : "student@example.com"
    let coach =
      scenario == .noCoach || scenario == .empty
      ? nil
      : ActiveCoachContext(
        coachID: StudentDemoSeed.coachID,
        coachDisplayName: scenario == .longIdentity
          ? "A very long coach display name for layout verification" : "Demo Coach")
    let store = StudentRootDemoPlanStore(
      studentID: studentID, plan: StudentDemoSeed.makePlanView())
    profile = MyProfileView(
      studentID: studentID, loginIdentifier: identifier, activeCoach: coach,
      plans: InMemoryStudentPlanRepository(store: store),
      e1rm: InMemoryE1RMRepository(), onboarding: ProfileDemoRepository(scenario: scenario),
      onLogout: onLogout)
  }

  public var body: some View { profile }
}

private actor ProfileDemoRepository: OnboardingRepository {
  private let scenario: ProfileDemoScenario
  private let base: InMemoryOnboardingRepository
  private var fetchCount = 0

  init(scenario: ProfileDemoScenario) {
    self.scenario = scenario
    let studentID = StudentDemoSeed.studentID
    let date = StudentDemoSeed.referenceDate
    let seed: OnboardingProfile?
    switch scenario {
    case .empty:
      seed = nil
    case .unanswered:
      seed = OnboardingProfile(userId: studentID, createdAt: date, updatedAt: date)
    case .longIdentity, .missingLift:
      seed = OnboardingProfile(
        userId: studentID, heightCm: 178, weightKg: 83,
        squat1RMKg: Decimal(string: "302.5"), bench1RMKg: 120,
        deadlift1RMKg: scenario == .missingLift ? nil : 220,
        isCompeting: true, competitionDate: "2026-10-13", targetWeightClass: "IPF 83kg",
        completedAt: date, createdAt: date, updatedAt: date)
    default:
      seed = StudentDemoSeed.makeOnboardingProfile(studentID: studentID)
    }
    base = InMemoryOnboardingRepository(studentId: studentID, seed: seed)
  }

  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    fetchCount += 1
    if scenario == .loading { try await Task.sleep(for: .seconds(3_600)) }
    if scenario == .failure || scenario == .refreshFailure && fetchCount == 2 {
      throw URLError(.notConnectedToInternet)
    }
    return try await base.fetchProfile(studentId: studentId)
  }

  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    try await base.upsert(patch)
  }

  func complete() async throws -> OnboardingProfile { try await base.complete() }
}
