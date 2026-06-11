import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private let studentId = OnboardingFixtures.studentId
private let fixedNow = Date(timeIntervalSince1970: 1_781_000_000)

private func makeRepo(seed: OnboardingProfile? = nil) -> InMemoryOnboardingRepository {
  InMemoryOnboardingRepository(studentId: studentId, seed: seed, now: { fixedNow })
}

// MARK: - Upsert three-state merge

@Test func upsertCreatesRowAndAppliesValues() async throws {
  let repo = makeRepo()
  var patch = OnboardingPatch()
  patch.gender = .value(.male)
  patch.heightCm = .value(178)

  let profile = try await repo.upsert(patch)

  #expect(profile.gender == .male)
  #expect(profile.heightCm == 178)
  #expect(profile.weightKg == nil)
  #expect(!profile.isCompleted)
}

@Test func absentKeepsAndNullClears() async throws {
  let repo = makeRepo(seed: OnboardingFixtures.serverProfile())
  var patch = OnboardingPatch()
  patch.benchGrip = .null
  patch.weightKg = .value(61)

  let profile = try await repo.upsert(patch)

  #expect(profile.weightKg == 61)  // value writes
  #expect(profile.benchGrip == nil)  // null clears
  #expect(profile.gender == .female)  // absent keeps
  #expect(profile.heightCm == 165)
}

// MARK: - Completion gate mirror (18 + 1 conditional)

@Test func completeWithoutRowReportsAllRequiredFields() async {
  let repo = makeRepo()
  await #expect(throws: OnboardingError.self) {
    try await repo.complete()
  }
  do {
    _ = try await repo.complete()
  } catch let OnboardingError.incomplete(missing) {
    #expect(missing.count == 18)
    #expect(missing.contains("unit_preference"))
    #expect(missing.contains("is_competing"))
  } catch {
    Issue.record("unexpected error \(error)")
  }
}

@Test func completeListsExactMissingFields() async throws {
  let repo = makeRepo()
  var draft = OnboardingFixtures.completeDraft()
  draft.sleepHours = nil
  draft.gymTier = nil
  _ = try await repo.upsert(draft.fullPatch())

  do {
    _ = try await repo.complete()
    Issue.record("expected incomplete")
  } catch let OnboardingError.incomplete(missing) {
    #expect(Set(missing) == ["sleep_hours", "gym_tier"])
  }
}

@Test func competitionDateIsRequiredOnlyWhenCompeting() async throws {
  let repo = makeRepo()
  var draft = OnboardingFixtures.completeDraft()
  draft.isCompeting = true
  draft.competitionDate = nil
  _ = try await repo.upsert(draft.fullPatch())

  do {
    _ = try await repo.complete()
    Issue.record("expected incomplete")
  } catch let OnboardingError.incomplete(missing) {
    #expect(missing == ["competition_date"])
  }
}

@Test func completeSucceedsAndIsIdempotent() async throws {
  let repo = makeRepo()
  _ = try await repo.upsert(OnboardingFixtures.completeDraft().fullPatch())

  let completed = try await repo.complete()
  #expect(completed.isCompleted)
  let original = completed.completedAt

  let again = try await repo.complete()
  #expect(again.completedAt == original)  // original timestamp survives
}

// MARK: - 1RM lock (spec 032 D2 / risk 6)

@Test func oneRMPatchAfterCompletionThrowsLocked() async throws {
  let repo = makeRepo()
  _ = try await repo.upsert(OnboardingFixtures.completeDraft().fullPatch())
  _ = try await repo.complete()

  var patch = OnboardingPatch()
  patch.squat1RMKg = .value(190)
  await #expect(throws: OnboardingError.oneRMLocked) {
    try await repo.upsert(patch)
  }
}

@Test func nonOneRMEditsRemainAllowedAfterCompletion() async throws {
  let repo = makeRepo()
  _ = try await repo.upsert(OnboardingFixtures.completeDraft().fullPatch())
  _ = try await repo.complete()

  var patch = OnboardingPatch()
  patch.gymTier = .value(.professional)
  let profile = try await repo.upsert(patch)
  #expect(profile.gymTier == .professional)
  #expect(profile.isCompleted)
}

@Test func oneRMEditsAreAllowedBeforeCompletion() async throws {
  let repo = makeRepo()
  var patch = OnboardingPatch()
  patch.squat1RMKg = .value(180)
  let profile = try await repo.upsert(patch)
  #expect(profile.squat1RMKg == 180)
}

@Test func fetchReturnsNilForUnknownStudent() async throws {
  let repo = makeRepo(seed: OnboardingFixtures.serverProfile())
  let other = UUID(uuidString: "0d000000-0000-0000-0000-000000000003")!
  let profile = try await repo.fetchProfile(studentId: other)
  #expect(profile == nil)
}
