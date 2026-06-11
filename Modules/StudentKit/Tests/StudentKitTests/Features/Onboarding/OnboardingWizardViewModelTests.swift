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
@Test func loadWithoutAnyDataStartsAtStepOne() async {
  let harness = WizardHarness()
  await harness.viewModel.load()
  #expect(harness.viewModel.phase == .editing)
  #expect(harness.viewModel.step == 1)
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
  #expect(harness.repo.upsertedPatches[0].sleepHours == .value(4))
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
