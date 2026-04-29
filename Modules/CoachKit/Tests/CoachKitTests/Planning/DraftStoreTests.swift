import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftStoreSavesAndLoadsDraft() throws {
  let store = try PlanningFixtures.store()
  let draft = PlanningFixtures.draft()

  try store.saveDraft(draft)
  let loaded = try store.loadDraft(traineeID: PlanningFixtures.activeStudentID)

  #expect(loaded?.id == draft.id)
  #expect(loaded?.planWeeks == 4)
  #expect(loaded?.draftDays.first?.assignedLiftFamilyRawValues == ["squat"])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftStoreDeleteDraftRemovesMatchingTrainee() throws {
  let store = try PlanningFixtures.store()
  let draft = PlanningFixtures.draft()

  try store.saveDraft(draft)
  try store.deleteDraft(traineeID: PlanningFixtures.activeStudentID)

  #expect(try store.loadDraft(traineeID: PlanningFixtures.activeStudentID) == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftStoreLoadDraftKeepsOtherStudents() throws {
  let store = try PlanningFixtures.store()
  let draft = PlanningFixtures.draft()
  let otherDraft = DraftTrainingPlan(
    traineeID: PlanningFixtures.secondActiveStudentID,
    name: "李四 1 周计划",
    startDate: PlanningFixtures.now,
    endDate: PlanningFixtures.now.addingTimeInterval(518_400),
    planWeeks: 1
  )

  try store.saveDraft(draft)
  try store.saveDraft(otherDraft)
  try store.deleteDraft(traineeID: PlanningFixtures.activeStudentID)

  #expect(try store.loadDraft(traineeID: PlanningFixtures.activeStudentID) == nil)
  #expect(try store.loadDraft(traineeID: PlanningFixtures.secondActiveStudentID)?.planWeeks == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftStoreDeleteAllRemovesEveryDraft() async throws {
  let store = try PlanningFixtures.store()
  let draft = PlanningFixtures.draft()
  let otherDraft = DraftTrainingPlan(
    traineeID: PlanningFixtures.secondActiveStudentID,
    name: "李四 1 周计划",
    startDate: PlanningFixtures.now,
    endDate: PlanningFixtures.now.addingTimeInterval(518_400),
    planWeeks: 1
  )

  try store.saveDraft(draft)
  try store.saveDraft(otherDraft)

  try await store.deleteAll()

  #expect(try store.loadDraft(traineeID: PlanningFixtures.activeStudentID) == nil)
  #expect(try store.loadDraft(traineeID: PlanningFixtures.secondActiveStudentID) == nil)
}
