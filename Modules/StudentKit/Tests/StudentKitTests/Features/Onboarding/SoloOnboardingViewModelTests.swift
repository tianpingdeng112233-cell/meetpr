import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing

@testable import StudentKit

private let soloID = UUID(uuidString: "AAAAAAAA-0000-4000-8000-00000000A046")!

private func makeRepo(seed: OnboardingProfile? = nil) -> InMemoryOnboardingRepository {
  InMemoryOnboardingRepository(studentId: soloID, seed: seed, role: .selfTrainStudent)
}

/// 跳过语义 (spec 046 §2): skipping still completes with the unit alone, so
/// the gate never re-prompts — and no baseline fields leak into the profile.
@MainActor
@Test func soloSkipCompletesWithUnitOnly() async throws {
  let repo = makeRepo()
  var completed = false
  let viewModel = SoloOnboardingViewModel(repository: repo) { completed = true }

  viewModel.advanceToBaseline()
  viewModel.draft.squat1RMKg = 140  // typed but skipped → must NOT be saved
  await viewModel.finish(skippingBaseline: true)

  #expect(completed)
  let profile = try #require(try await repo.fetchProfile(studentId: soloID))
  #expect(profile.isCompleted)
  #expect(profile.unitPreference == .kg)
  #expect(profile.squat1RMKg == nil)
}

@MainActor
@Test func soloFinishSavesFilledBaselineFields() async throws {
  let repo = makeRepo()
  var completed = false
  let viewModel = SoloOnboardingViewModel(repository: repo) { completed = true }

  viewModel.unitPreference = .kg
  viewModel.weightText = "82.5"
  viewModel.advanceToBaseline()
  viewModel.draft.squat1RMKg = 140
  viewModel.draft.bench1RMKg = nil
  viewModel.draft.deadlift1RMKg = 180
  await viewModel.finish(skippingBaseline: false)

  #expect(completed)
  let profile = try #require(try await repo.fetchProfile(studentId: soloID))
  #expect(profile.isCompleted)
  #expect(profile.weightKg == Decimal(string: "82.5"))
  #expect(profile.squat1RMKg == 140)
  #expect(profile.bench1RMKg == nil)
  #expect(profile.deadlift1RMKg == 180)
}

@MainActor
@Test func soloFinishFailureSurfacesRetryAndKeepsFlow() async {
  let repo = FailingOnboardingRepository()
  var completed = false
  let viewModel = SoloOnboardingViewModel(repository: repo) { completed = true }

  viewModel.advanceToBaseline()
  await viewModel.finish(skippingBaseline: true)

  #expect(!completed)
  guard case .failed = viewModel.state else {
    Issue.record("Expected failed state, got \(viewModel.state)")
    return
  }
}

/// Solo baseline stays editable after completion (backend spec 013 mirror):
/// the skip-then-backfill path must not hit ONE_RM_LOCKED.
@Test func inMemorySoloRepoAllowsBaselineBackfillAfterCompletion() async throws {
  let repo = makeRepo()
  var unitOnly = OnboardingPatch()
  unitOnly.unitPreference = .value(.kg)
  _ = try await repo.upsert(unitOnly)
  _ = try await repo.complete()

  var backfill = OnboardingPatch()
  backfill.squat1RMKg = .value(150)
  let profile = try await repo.upsert(backfill)
  #expect(profile.squat1RMKg == 150)
}

/// Coached semantics unchanged: the lock still throws after completion.
@Test func inMemoryCoachedRepoKeepsOneRMLock() async throws {
  let repo = InMemoryOnboardingRepository(
    studentId: soloID,
    seed: StudentDemoSeed.makeOnboardingProfile(studentID: soloID)
  )
  var patch = OnboardingPatch()
  patch.squat1RMKg = .value(150)
  await #expect(throws: OnboardingError.oneRMLocked) {
    _ = try await repo.upsert(patch)
  }
}

@MainActor
@Test func gateNeedsOnboardingOnlyUntilCompleted() {
  #expect(SoloOnboardingGateView<EmptyView>.needsOnboarding(nil))
  let incomplete = OnboardingProfile(userId: soloID, createdAt: Date(), updatedAt: Date())
  #expect(SoloOnboardingGateView<EmptyView>.needsOnboarding(incomplete))
  let completed = OnboardingProfile(
    userId: soloID, completedAt: Date(), createdAt: Date(), updatedAt: Date())
  #expect(!SoloOnboardingGateView<EmptyView>.needsOnboarding(completed))
}

private struct FailingOnboardingRepository: OnboardingRepository {
  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    throw URLError(.notConnectedToInternet)
  }

  func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    throw URLError(.notConnectedToInternet)
  }

  func complete() async throws -> OnboardingProfile {
    throw URLError(.notConnectedToInternet)
  }
}
