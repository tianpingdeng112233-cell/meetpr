import CoreModels
import Foundation
import RepositoryContracts

@testable import StudentKit

enum OnboardingFixtures {
  static let studentId = BindFixtures.studentId
  static let serverUpdatedAt = Date(timeIntervalSince1970: 1_780_000_000)

  /// All 18 required fields + competing with a date — completes cleanly.
  static func completeDraft() -> OnboardingDraft {
    var draft = OnboardingDraft()
    draft.unitPreference = .kg
    draft.gender = .male
    draft.birthDate = "2001-03-15"
    draft.heightCm = 178
    draft.weightKg = 83
    draft.trainingYears = 3
    draft.squatStance = .lowBar
    draft.deadliftStyle = .conventional
    draft.squat1RMKg = 180
    draft.bench1RMKg = 120
    draft.deadlift1RMKg = 220
    draft.trainingDays = [.mon, .wed, .fri]
    draft.gymTier = .commercial
    draft.equipmentOverrides = EquipmentCatalog.prefill(for: .commercial)
    draft.dailyLifeIntensity = 3
    draft.lifeStress = 2
    draft.recoverySpeed = 3
    draft.sleepHours = 4
    draft.isCompeting = false
    return draft
  }

  static func serverProfile(updatedAt: Date = serverUpdatedAt) -> OnboardingProfile {
    OnboardingProfile(
      userId: studentId,
      unitPreference: .kg,
      gender: .female,
      birthDate: "1999-01-01",
      heightCm: 165,
      weightKg: 60,
      trainingYears: 2,
      squatStance: .highBar,
      deadliftStyle: .sumo,
      createdAt: updatedAt.addingTimeInterval(-86_400),
      updatedAt: updatedAt
    )
  }
}

/// Scriptable OnboardingRepository: records upsert patches; complete pops
/// scripted results.
final class ScriptedOnboardingRepository: OnboardingRepository, @unchecked Sendable {
  enum CompleteResult {
    case success(OnboardingProfile)
    case failure(any Error)
  }

  private let lock = NSLock()
  var fetchResult: OnboardingProfile?
  var fetchError: (any Error)?
  /// One error per upsert call, popped in order; nil entries = success.
  var upsertErrors: [(any Error)?] = []
  var completeResults: [CompleteResult] = []
  private(set) var upsertedPatches: [OnboardingPatch] = []
  private(set) var completeCallCount = 0

  init() {}

  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    if let fetchError { throw fetchError }
    return fetchResult
  }

  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    lock.lock()
    upsertedPatches.append(patch)
    let error = upsertErrors.isEmpty ? nil : upsertErrors.removeFirst()
    lock.unlock()
    if let error { throw error }
    return fetchResult
      ?? OnboardingProfile(
        userId: OnboardingFixtures.studentId, createdAt: Date(), updatedAt: Date())
  }

  func complete() async throws -> OnboardingProfile {
    lock.lock()
    completeCallCount += 1
    let result = completeResults.isEmpty ? nil : completeResults.removeFirst()
    lock.unlock()
    switch result {
    case .success(let profile): return profile
    case .failure(let error): throw error
    case nil:
      return OnboardingProfile(
        userId: OnboardingFixtures.studentId,
        completedAt: Date(),
        createdAt: Date(),
        updatedAt: Date()
      )
    }
  }
}

func makeTemporaryDraftStore() -> LocalOnboardingDraftStore {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("onboarding-tests-\(UUID().uuidString)", isDirectory: true)
  return LocalOnboardingDraftStore(directory: directory)
}
