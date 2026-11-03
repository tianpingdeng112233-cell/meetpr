import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
private struct WizardHarness {
  let viewModel: OnboardingWizardViewModel
  let repo: ScriptedOnboardingRepository
  let bind: ScriptedBindRepository
  let stash: StashSpy
  let draftStore: LocalOnboardingDraftStore
  let outcomes: OutcomeRecorder

  init(
    repo: ScriptedOnboardingRepository = ScriptedOnboardingRepository(),
    bind: ScriptedBindRepository = ScriptedBindRepository(),
    stash: StashSpy = StashSpy(),
    draftStore: LocalOnboardingDraftStore = makeTemporaryDraftStore()
  ) {
    self.repo = repo
    self.bind = bind
    self.stash = stash
    self.draftStore = draftStore
    let outcomes = OutcomeRecorder()
    self.outcomes = outcomes
    self.viewModel = OnboardingWizardViewModel(
      studentId: OnboardingFixtures.studentId,
      repo: repo,
      draftStore: draftStore,
      bind: bind,
      stash: stash,
      onCompleted: { await outcomes.record($0) },
      now: { OnboardingFixtures.serverUpdatedAt.addingTimeInterval(7_200) }
    )
  }
}

actor OutcomeRecorder {
  private(set) var outcomes: [BindHandoffOutcome] = []

  func record(_ outcome: BindHandoffOutcome) {
    outcomes.append(outcome)
  }
}

// MARK: - Load / resume (D6)

@MainActor
@Test func spec095WizardReachesExtrasAsItsFourthAndLastStep() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()
  for expected in 2...4 {
    await harness.viewModel.advance()
    #expect(harness.viewModel.step == expected)
  }
  #expect(harness.viewModel.isLastStep)
  harness.viewModel.draft.isCompeting = true
  #expect(!harness.viewModel.canAdvance)
  harness.viewModel.draft.competitionDate = "2026-12-01"
  harness.viewModel.draft.targetWeightClass = "IPF · 83 kg"
  #expect(harness.viewModel.canAdvance)
}

@MainActor
@Test func loadWithoutAnyDataStartsAtStepOne() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  #expect(harness.viewModel.phase == .editing)
  #expect(harness.viewModel.step == 1)
}

@MainActor
@Test func spec095LegacyDraftSubmissionOmitsRemovedFieldsAndKeepsServerValues() async throws {
  let harness = WizardHarness()
  await harness.viewModel.load()
  var legacy = OnboardingFixtures.completeDraft()
  legacy.muscleGroupsToStrengthen = [.back]
  legacy.noteToCoach = "Keep this note"
  harness.viewModel.draft = legacy
  await harness.viewModel.complete()

  let patch = try #require(harness.repo.upsertedPatches.last)
  #expect(patch.trainingDays == .absent)
  #expect(patch.gymTier == .absent)
  #expect(patch.equipmentOverrides == .absent)
  #expect(patch.dailyLifeIntensity == .absent)
  #expect(patch.lifeStress == .absent)
  #expect(patch.recoverySpeed == .absent)
  #expect(patch.sleepHours == .absent)
  #expect(patch.muscleGroupsToStrengthen == .absent)
  #expect(patch.uploadAttachmentIds == .absent)
  #expect(patch.noteToCoach == .value("Keep this note"))
  #expect(patch.isCompeting == .value(false))

  let server = StudentDemoSeed.makeOnboardingProfile(studentID: OnboardingFixtures.studentId)
  let saved = InMemoryOnboardingRepository.applied(
    patch, to: server, updatedAt: OnboardingFixtures.serverUpdatedAt)
  #expect(saved.trainingDays == server.trainingDays)
  #expect(saved.gymTier == server.gymTier)
  #expect(saved.equipmentOverrides == server.equipmentOverrides)
  #expect(saved.dailyLifeIntensity == server.dailyLifeIntensity)
  #expect(saved.lifeStress == server.lifeStress)
  #expect(saved.recoverySpeed == server.recoverySpeed)
  #expect(saved.sleepHours == server.sleepHours)
  #expect(saved.muscleGroupsToStrengthen == server.muscleGroupsToStrengthen)
}

@MainActor
@Test func loadPrefillsFromServerAndResumesFirstIncompleteStep() async {
  let harness = WizardHarness()
  harness.repo.fetchResult = OnboardingFixtures.serverProfile()  // step 1-2 filled
  await harness.viewModel.load()

  #expect(harness.viewModel.draft.gender == .female)
  #expect(harness.viewModel.step == 3)  // 1RMs are the first gap
}

@MainActor
@Test func loadMergesNewerLocalDraftOverServer() async {
  let harness = WizardHarness()
  harness.repo.fetchResult = OnboardingFixtures.serverProfile()
  var local = OnboardingDraft()
  local.gender = .male
  local.squat1RMKg = 100
  local.savedAt = OnboardingFixtures.serverUpdatedAt.addingTimeInterval(3_600)
  try? await harness.draftStore.save(local, studentId: OnboardingFixtures.studentId)

  await harness.viewModel.load()

  #expect(harness.viewModel.draft.gender == .male)
  #expect(harness.viewModel.draft.squat1RMKg == 100)
  #expect(harness.viewModel.draft.heightCm == 165)  // server kept
}

// MARK: - Advance (step gating + per-step PUT)

@MainActor
@Test(arguments: [4, 5, 6, 7])
func spec095OldDraftResumesAtExtrasAndNormalizesProgress(oldStep: Int) async throws {
  let harness = WizardHarness()
  var legacy = OnboardingFixtures.completeDraft()
  legacy.furthestStep = oldStep
  legacy.savedAt = OnboardingFixtures.serverUpdatedAt
  try await harness.draftStore.save(legacy, studentId: OnboardingFixtures.studentId)
  await harness.viewModel.load()
  #expect(harness.viewModel.usedDraftResume)
  #expect(harness.viewModel.step == 4)
  #expect(harness.viewModel.isLastStep)
  #expect(harness.viewModel.draft.furthestStep == 4)
  #expect(harness.viewModel.draft.sleepHours == legacy.sleepHours)
  await harness.viewModel.saveAndExit()
  let saved = await harness.draftStore.load(studentId: OnboardingFixtures.studentId)
  #expect(saved?.furthestStep == 4)
  #expect(harness.repo.upsertedPatches.last?.sleepHours == .absent)
  #expect(harness.repo.upsertedPatches.last?.isCompeting == .value(false))
}

@MainActor
@Test func advanceIsBlockedUntilStepIsComplete() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  #expect(!harness.viewModel.canAdvance)
  await harness.viewModel.advance()
  #expect(harness.viewModel.step == 1)
  #expect(harness.repo.upsertedPatches.isEmpty)
}

@MainActor
@Test func advancePutsOnlyCurrentStepFieldsAndMovesOn() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.advance()

  #expect(harness.viewModel.step == 2)
  #expect(harness.repo.upsertedPatches.count == 1)
  let patch = harness.repo.upsertedPatches[0]
  #expect(patch.unitPreference == .value(.kg))
  #expect(patch.trainingYears == .absent)  // step 2 field not in step 1 PUT
  #expect(patch.squat1RMKg == .absent)
}

@MainActor
@Test func advanceSavesDraftLocallyForResume() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.advance()

  let saved = await harness.draftStore.load(studentId: OnboardingFixtures.studentId)
  #expect(saved?.unitPreference == .kg)
  #expect(saved?.furthestStep == 2)
}

@MainActor
@Test func stepPutFailureShowsBannerButNeverBlocks() async {
  let harness = WizardHarness()
  harness.repo.upsertErrors = [TransportFailure()]
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.advance()

  #expect(harness.viewModel.step == 2)  // D6: full PUT is the catch-all
  #expect(harness.viewModel.saveBanner != nil)
}

// MARK: - Complete (full PUT → gate → handoff)

@MainActor
@Test func completeRunsFullPutBeforeCompleteCall() async {
  let harness = WizardHarness()
  harness.stash.stash(BindFixtures.pendingCode(), studentId: OnboardingFixtures.studentId)
  let sent = BindFixtures.request(status: .pending)
  let bindHarness = harness.bind
  bindHarness.scriptSubmit(.success(sent))
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  #expect(harness.repo.upsertedPatches.count == 1)
  #expect(harness.repo.upsertedPatches[0].gender == .value(.male))  // full patch
  #expect(harness.repo.upsertedPatches[0].sleepHours == .absent)
  #expect(harness.repo.completeCallCount == 1)
  // Draft cleared after success.
  let saved = await harness.draftStore.load(studentId: OnboardingFixtures.studentId)
  #expect(saved == nil)
  // Handoff: 201 → requestSent.
  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes == [.requestSent(sent)])
  #expect(harness.stash.peek(studentId: OnboardingFixtures.studentId) == nil)
}

@MainActor
@Test func completeFullPutFailureStopsBeforeCompleteCall() async {
  let harness = WizardHarness()
  harness.repo.upsertErrors = [TransportFailure()]
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  #expect(harness.repo.completeCallCount == 0)
  #expect(harness.viewModel.saveBanner != nil)
  #expect(harness.viewModel.phase == .editing)
}

@MainActor
@Test func incompleteJumpsToEarliestMissingStepAndHighlights() async {
  let harness = WizardHarness()
  harness.repo.completeResults = [
    .failure(OnboardingError.incomplete(missingFields: ["sleep_hours", "gender"]))
  ]
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  #expect(harness.viewModel.step == 1)  // gender is the earliest
  #expect(harness.viewModel.highlightedFields == ["sleep_hours", "gender"])
  #expect(harness.viewModel.phase == .editing)
  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes.isEmpty)
}

// MARK: - Handoff decision tree (spec 032 §6, 5 paths)

@MainActor
@Test func handoffWithoutStashRequestsReload() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes == [.needsReload])
}

@MainActor
@Test func handoffInvalidCodeClearsStashAndReportsDisplayName() async {
  let harness = WizardHarness()
  harness.stash.stash(BindFixtures.pendingCode(), studentId: OnboardingFixtures.studentId)
  harness.bind.scriptSubmit(.failure(BindRequestError.invalidCode))
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes == [.invalidCode(displayName: "张三")])
  #expect(harness.stash.peek(studentId: OnboardingFixtures.studentId) == nil)
}

@MainActor
@Test func handoffAlreadyPendingRequestsReload() async {
  let harness = WizardHarness()
  harness.stash.stash(BindFixtures.pendingCode(), studentId: OnboardingFixtures.studentId)
  harness.bind.scriptSubmit(.failure(BindRequestError.alreadyPending))
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes == [.needsReload])
}

@MainActor
@Test func handoffNetworkFailureKeepsStashAndOffersRetry() async {
  let harness = WizardHarness()
  harness.stash.stash(BindFixtures.pendingCode(), studentId: OnboardingFixtures.studentId)
  harness.bind.scriptSubmit(.failure(TransportFailure()))
  await harness.viewModel.load()
  harness.viewModel.draft = OnboardingFixtures.completeDraft()

  await harness.viewModel.complete()

  #expect(harness.viewModel.phase == .handoffFailed)
  #expect(harness.stash.peek(studentId: OnboardingFixtures.studentId) != nil)
  let outcomesBefore = await harness.outcomes.outcomes
  #expect(outcomesBefore.isEmpty)

  // [重试发送] succeeds on the second attempt.
  let sent = BindFixtures.request(status: .pending)
  harness.bind.scriptSubmit(.success(sent))
  await harness.viewModel.retryHandoff()

  let outcomes = await harness.outcomes.outcomes
  #expect(outcomes == [.requestSent(sent)])
  #expect(harness.stash.peek(studentId: OnboardingFixtures.studentId) == nil)
}

@MainActor
@Test func spec095CompletedProfileSkipsWizardAndClearsStaleDraft() async throws {
  let harness = WizardHarness()
  harness.repo.fetchResult = StudentDemoSeed.makeOnboardingProfile(
    studentID: OnboardingFixtures.studentId)
  try await harness.draftStore.save(
    OnboardingFixtures.completeDraft(), studentId: OnboardingFixtures.studentId)
  await harness.viewModel.load()
  #expect(harness.viewModel.phase == .completing)
  #expect(harness.repo.upsertedPatches.isEmpty)
  #expect(await harness.outcomes.outcomes == [.needsReload])
  #expect(await harness.draftStore.load(studentId: OnboardingFixtures.studentId) == nil)
}
