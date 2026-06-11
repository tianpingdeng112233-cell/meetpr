import Foundation
import Testing

@testable import StudentKit

@Test func draftSaveLoadClearRoundTrip() async throws {
  let store = makeTemporaryDraftStore()
  let studentId = OnboardingFixtures.studentId
  var draft = OnboardingFixtures.completeDraft()
  draft.savedAt = OnboardingFixtures.serverUpdatedAt
  draft.furthestStep = 4

  let empty = await store.load(studentId: studentId)
  #expect(empty == nil)

  try await store.save(draft, studentId: studentId)
  let loaded = await store.load(studentId: studentId)
  #expect(loaded == draft)

  await store.clear(studentId: studentId)
  let cleared = await store.load(studentId: studentId)
  #expect(cleared == nil)
}

@Test func corruptedDraftFileReadsAsNil() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("onboarding-tests-\(UUID().uuidString)", isDirectory: true)
  let store = LocalOnboardingDraftStore(directory: directory)
  let studentId = OnboardingFixtures.studentId

  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let file = directory.appendingPathComponent("draft-\(studentId.uuidString).json")
  try Data("not json {{{".utf8).write(to: file)

  let loaded = await store.load(studentId: studentId)
  #expect(loaded == nil)  // resilience copy: corrupt = absent, never crash
}

@Test func draftsAreIsolatedPerStudent() async throws {
  let store = makeTemporaryDraftStore()
  let studentA = OnboardingFixtures.studentId
  let studentB = UUID(uuidString: "0c000000-0000-0000-0000-000000000002")!

  var draftA = OnboardingDraft()
  draftA.gender = .male
  try await store.save(draftA, studentId: studentA)

  let loadedB = await store.load(studentId: studentB)
  #expect(loadedB == nil)

  await store.clear(studentId: studentB)
  let loadedA = await store.load(studentId: studentA)
  #expect(loadedA?.gender == .male)
}
