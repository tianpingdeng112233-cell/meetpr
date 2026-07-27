import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview onboarding profile reads for CoachKit (the StudentKit
/// in-memory repository is unreachable across the Kit boundary).
public actor InMemoryCoachStudentProfileReader: OnboardingProfileReading {
  private let profilesByStudent: [UUID: OnboardingProfile]

  public init(profiles: [OnboardingProfile] = []) {
    profilesByStudent = Dictionary(
      profiles.map { ($0.userId, $0) },
      uniquingKeysWith: { _, new in new }
    )
  }

  public func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    profilesByStudent[studentId]
  }
}
