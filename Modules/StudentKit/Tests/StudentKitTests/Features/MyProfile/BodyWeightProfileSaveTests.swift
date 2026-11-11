import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func bodyWeightProfileWritesOnlyEditedWeightButSingleEditorAlwaysLogsToday() async throws {
  let profile = OnboardingFixtures.serverProfile()
  let now = profile.updatedAt.addingTimeInterval(2 * 86_400)
  let repo = InMemoryOnboardingRepository(studentId: profile.userId, seed: profile, now: { now })
  let model = MyProfileViewModel(studentId: profile.userId, repo: repo)
  var draft = OnboardingDraft.from(profile)
  draft.heightCm = 170
  #expect(
    await model.saveCard(
      draft.profilePatch(for: .basics), kind: .basics, originalWeight: profile.weightKg))
  #expect(try await repo.fetchBodyWeights().count == 1)
  #expect(try await repo.fetchProfile(studentId: profile.userId)?.heightCm == 170)
  #expect(
    await model.saveCard(
      draft.profilePatch(for: .weight), kind: .weight, originalWeight: profile.weightKg))
  #expect(try await repo.fetchBodyWeights().count == 2)
  draft.weightKg = 84
  #expect(
    await model.saveCard(
      draft.profilePatch(for: .basics), kind: .basics, originalWeight: profile.weightKg))
  let records = try await repo.fetchBodyWeights()
  #expect(records.count == 2)
  #expect(records.last?.weightKg == 84)
  #expect(try await repo.fetchProfile(studentId: profile.userId)?.weightKg == 84)
}

@MainActor
@Test(arguments: [true, false])
func bodyWeightReloadDiscardsResponsesStartedBeforeDeletion(forProfile: Bool) async throws {
  let repo = DelayedWeightProfileRepository()
  let studentID = UUID()
  let profile = MyProfileViewModel(studentId: studentID, repo: repo)
  let today = DashboardProfileMetricsViewModel(onboarding: repo)
  let first = Task {
    if forProfile { await profile.reload() } else { await today.load(studentID: studentID) }
  }
  await repo.waitForFirstRead()
  if forProfile { await profile.reload() } else { await today.load(studentID: studentID) }
  await repo.finishOldRead()
  await first.value
  if forProfile {
    guard case .loaded(let snapshot) = profile.state else {
      Issue.record("Expected the loaded profile after deletion")
      return
    }
    #expect(snapshot.weightKg == nil)
  } else {
    #expect(today.metrics?.bodyWeightText == nil)
  }
}

private actor DelayedWeightProfileRepository: OnboardingRepository {
  private var firstRead: CheckedContinuation<OnboardingProfile?, Never>?
  private var firstReadWaiter: CheckedContinuation<Void, Never>?
  private var hasRead = false
  private let old = OnboardingFixtures.serverProfile()

  func fetchProfile(studentId: UUID) async -> OnboardingProfile? {
    if !hasRead {
      hasRead = true
      firstReadWaiter?.resume()
      firstReadWaiter = nil
      return await withCheckedContinuation { firstRead = $0 }
    }
    return OnboardingProfile(userId: studentId, createdAt: old.createdAt, updatedAt: old.updatedAt)
  }

  func waitForFirstRead() async {
    if hasRead { return }
    await withCheckedContinuation { firstReadWaiter = $0 }
  }

  func finishOldRead() {
    firstRead?.resume(returning: old)
    firstRead = nil
  }

  func upsert(_ patch: OnboardingPatch) throws -> OnboardingProfile {
    throw BodyWeightError.unavailable
  }
  func complete() throws -> OnboardingProfile { throw BodyWeightError.unavailable }
}
