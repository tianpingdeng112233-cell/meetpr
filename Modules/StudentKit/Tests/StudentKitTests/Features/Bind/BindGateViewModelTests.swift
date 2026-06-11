import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// State machine decision table (spec 031 §6):
// mine ∈ {nil, pending, accepted, rejected, expired, cancelled}
// × stash ∈ {none, some} × onboardingComplete ∈ {true, false}.

@MainActor
private struct GateHarness {
  let gate: BindGateViewModel
  let repo: ScriptedBindRepository
  let stash: StashSpy
}

@MainActor
private func makeGate(
  mine: ScriptedBindRepository.MineResult,
  extraMine: [ScriptedBindRepository.MineResult] = [],
  submit: [ScriptedBindRepository.SubmitResult] = [],
  stash: StashSpy = StashSpy(),
  onboardingComplete: Bool = true
) -> GateHarness {
  let repo = ScriptedBindRepository(mine: [mine] + extraMine, submit: submit)
  let gate = BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: repo,
    stash: stash,
    isOnboardingComplete: { onboardingComplete }
  )
  return GateHarness(gate: gate, repo: repo, stash: stash)
}

// MARK: - Direct states (no stash)

@MainActor
@Test func acceptedGoesStraightToBound() async {
  let accepted = BindFixtures.request(status: .accepted)
  let harness = makeGate(mine: .success(accepted))
  await harness.gate.load()
  #expect(harness.gate.state == .bound(accepted))
}

@MainActor
@Test func pendingGoesToPendingAcceptance() async {
  let pending = BindFixtures.request(status: .pending)
  let harness = makeGate(mine: .success(pending))
  await harness.gate.load()
  #expect(harness.gate.state == .pendingAcceptance(pending))
}

@MainActor
@Test func noHistoryLandsOnEnterCodeWithoutNotice() async {
  let harness = makeGate(mine: .success(nil))
  await harness.gate.load()
  #expect(harness.gate.state == .needsCode(prefillDisplayName: nil, notice: nil))
}

@MainActor
@Test func rejectedLandsOnEnterCodeWithNeutralNotice() async {
  let harness = makeGate(mine: .success(BindFixtures.request(status: .rejected)))
  await harness.gate.load()
  #expect(harness.gate.state == .needsCode(prefillDisplayName: nil, notice: .coachNotAccepting))
}

@MainActor
@Test func expiredLandsOnEnterCodeWithExpiryNotice() async {
  let harness = makeGate(mine: .success(BindFixtures.request(status: .expired)))
  await harness.gate.load()
  #expect(harness.gate.state == .needsCode(prefillDisplayName: nil, notice: .requestExpired))
}

@MainActor
@Test func cancelledLandsOnEnterCodeSilently() async {
  let harness = makeGate(mine: .success(BindFixtures.request(status: .cancelled)))
  await harness.gate.load()
  #expect(harness.gate.state == .needsCode(prefillDisplayName: nil, notice: nil))
}

@MainActor
@Test func fetchFailureNeverFallsThroughToTabs() async {
  let harness = makeGate(mine: .failure(TransportFailure()))
  await harness.gate.load()
  #expect(harness.gate.state == .failed)
}

// MARK: - Rejection copy stays neutral (spec 031 D8)

@Test func noticeCopyNeverSaysRejected() {
  let notices: [BindNotice] = [.coachNotAccepting, .requestExpired, .invalidCode, .network]
  for notice in notices {
    #expect(!notice.message.contains("拒绝"))
    #expect(!notice.message.lowercased().contains("reject"))
  }
}

// MARK: - Stash resume (cold start, spec 031 §6 resolveUnbound)

@MainActor
@Test func stashWithIncompleteOnboardingResumesWizard() async {
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(mine: .success(nil), stash: stash, onboardingComplete: false)
  await harness.gate.load()
  #expect(harness.gate.state == .needsOnboarding(BindFixtures.pendingCode()))
  #expect(harness.repo.submitCalls.isEmpty)
}

@MainActor
@Test func stashWithCompleteOnboardingAutoResubmits() async {
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let sent = BindFixtures.request(status: .pending)
  let harness = makeGate(mine: .success(nil), submit: [.success(sent)], stash: stash)
  await harness.gate.load()

  #expect(harness.gate.state == .pendingAcceptance(sent))
  #expect(harness.repo.submitCalls.count == 1)
  #expect(harness.repo.submitCalls.first?.code == "XK7MPQ2RVT")
  #expect(harness.repo.submitCalls.first?.displayName == "张三")
  #expect(stash.peek(studentId: BindFixtures.studentId) == nil)
}

@MainActor
@Test func resubmitInvalidCodeClearsStashAndPrefillsName() async {
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(
    mine: .success(nil), submit: [.failure(BindRequestError.invalidCode)], stash: stash)
  await harness.gate.load()

  #expect(harness.gate.state == .needsCode(prefillDisplayName: "张三", notice: .invalidCode))
  #expect(stash.peek(studentId: BindFixtures.studentId) == nil)
}

@MainActor
@Test func resubmitAlreadyPendingConvergesViaReread() async {
  let pending = BindFixtures.request(status: .pending)
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(
    mine: .success(nil),
    extraMine: [.success(pending)],
    submit: [.failure(BindRequestError.alreadyPending)],
    stash: stash
  )
  await harness.gate.load()

  #expect(harness.gate.state == .pendingAcceptance(pending))
  #expect(harness.repo.mineCallCount == 2)
  #expect(stash.peek(studentId: BindFixtures.studentId) == nil)
}

@MainActor
@Test func resubmitAlreadyBoundConvergesToBound() async {
  let accepted = BindFixtures.request(status: .accepted)
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(
    mine: .success(nil),
    extraMine: [.success(accepted)],
    submit: [.failure(BindRequestError.alreadyBound)],
    stash: stash
  )
  await harness.gate.load()

  #expect(harness.gate.state == .bound(accepted))
  #expect(stash.peek(studentId: BindFixtures.studentId) == nil)
}

@MainActor
@Test func resubmitNetworkFailureKeepsStash() async {
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(
    mine: .success(nil), submit: [.failure(TransportFailure())], stash: stash)
  await harness.gate.load()

  #expect(harness.gate.state == .needsCode(prefillDisplayName: "张三", notice: .network))
  #expect(stash.peek(studentId: BindFixtures.studentId) != nil)
}

@MainActor
@Test func stashIsIgnoredWhileRequestIsPending() async {
  // A live pending request wins over a stale stash — no resubmission.
  let pending = BindFixtures.request(status: .pending)
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let harness = makeGate(mine: .success(pending), stash: stash)
  await harness.gate.load()

  #expect(harness.gate.state == .pendingAcceptance(pending))
  #expect(harness.repo.submitCalls.isEmpty)
}

// MARK: - Callbacks

@MainActor
@Test func submittedOutcomeRequestSentLandsOnPending() async {
  let harness = makeGate(mine: .success(nil))
  await harness.gate.load()
  let sent = BindFixtures.request(status: .pending)
  await harness.gate.handleSubmitted(.requestSent(sent))
  #expect(harness.gate.state == .pendingAcceptance(sent))
}

@MainActor
@Test func submittedOutcomeStashedRoutesToWizard() async {
  let harness = makeGate(mine: .success(nil), onboardingComplete: false)
  await harness.gate.load()
  await harness.gate.handleSubmitted(.stashedForOnboarding(BindFixtures.pendingCode()))
  #expect(harness.gate.state == .needsOnboarding(BindFixtures.pendingCode()))
}

@MainActor
@Test func handoffInvalidCodeLandsOnEnterCodeWithPrefill() async {
  let harness = makeGate(mine: .success(nil), onboardingComplete: false)
  await harness.gate.load()
  await harness.gate.handleHandoff(.invalidCode(displayName: "张三"))
  #expect(harness.gate.state == .needsCode(prefillDisplayName: "张三", notice: .invalidCode))
}

@MainActor
@Test func handoffRequestSentLandsOnPending() async {
  let harness = makeGate(mine: .success(nil), onboardingComplete: false)
  await harness.gate.load()
  let sent = BindFixtures.request(status: .pending)
  await harness.gate.handleHandoff(.requestSent(sent))
  #expect(harness.gate.state == .pendingAcceptance(sent))
}

@MainActor
@Test func cancelCallbackClearsStashAndReturnsToEnterCode() async {
  let stash = StashSpy(seed: [BindFixtures.studentId: BindFixtures.pendingCode()])
  let pending = BindFixtures.request(status: .pending)
  let harness = makeGate(mine: .success(pending), stash: stash)
  await harness.gate.load()

  harness.gate.handleCancelled()

  #expect(harness.gate.state == .needsCode(prefillDisplayName: nil, notice: nil))
  #expect(stash.peek(studentId: BindFixtures.studentId) == nil)
}

// MARK: - Evaluation sub-route (spec 033 §11)

private struct StubMyEvaluations: EvaluationRepository {
  enum Behavior {
    case period(EvaluationPeriod?)
    case failure
  }

  let behavior: Behavior

  func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
    try resolve()
  }

  func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    try resolve()
  }

  func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    throw EvaluationError.notFound
  }

  private func resolve() throws -> EvaluationPeriod? {
    switch behavior {
    case .period(let period): return period
    case .failure: throw TransportFailure()
    }
  }
}

private func evaluationPeriod(completedAt: Date? = nil) -> EvaluationPeriod {
  EvaluationPeriod(
    id: UUID(uuidString: "0a000000-0000-0000-0000-0000000000e1")!,
    studentId: BindFixtures.studentId,
    coachId: BindFixtures.coachId,
    bindRequestId: UUID(uuidString: "0a000000-0000-0000-0000-00000000000f")!,
    startedAt: BindFixtures.referenceDate,
    expectedEndAt: BindFixtures.referenceDate.addingTimeInterval(7 * 86_400),
    completedAt: completedAt,
    completionType: completedAt == nil ? nil : "coach_completed",
    inProgress: completedAt == nil,
    overdue: false
  )
}

@MainActor
private func makeEvaluationGate(
  request: BindRequest,
  evaluations: StubMyEvaluations
) -> BindGateViewModel {
  BindGateViewModel(
    studentId: BindFixtures.studentId,
    bind: ScriptedBindRepository(mine: [.success(request)]),
    stash: StashSpy(),
    isOnboardingComplete: { true },
    evaluations: evaluations
  )
}

@MainActor
@Test func acceptedWithLiveEvaluationRoutesToEvaluationPage() async {
  let accepted = BindFixtures.request(status: .accepted)
  let period = evaluationPeriod()
  let gate = makeEvaluationGate(
    request: accepted, evaluations: StubMyEvaluations(behavior: .period(period)))
  await gate.load()
  #expect(gate.state == .evaluationActive(accepted, period))
}

@MainActor
@Test func acceptedWithCompletedEvaluationGoesToBound() async {
  let accepted = BindFixtures.request(status: .accepted)
  let period = evaluationPeriod(
    completedAt: BindFixtures.referenceDate.addingTimeInterval(86_400))
  let gate = makeEvaluationGate(
    request: accepted, evaluations: StubMyEvaluations(behavior: .period(period)))
  await gate.load()
  #expect(gate.state == .bound(accepted))
}

@MainActor
@Test func acceptedWithoutEvaluationGoesToBound() async {
  let accepted = BindFixtures.request(status: .accepted)
  let gate = makeEvaluationGate(
    request: accepted, evaluations: StubMyEvaluations(behavior: .period(nil)))
  await gate.load()
  #expect(gate.state == .bound(accepted))
}

@MainActor
@Test func evaluationFetchFailureLandsOnRetryNotBound() async {
  // A network blip must not let an in-evaluation student through to the
  // 5 tabs (Codex review P1): the gate shows the full-screen retry instead.
  let accepted = BindFixtures.request(status: .accepted)
  let gate = makeEvaluationGate(
    request: accepted, evaluations: StubMyEvaluations(behavior: .failure))
  await gate.load()
  #expect(gate.state == .failed)
}

@MainActor
@Test func skipEvaluationAcceptanceBypassesEvaluationRoute() async {
  // skipEvaluation accepts never consult the evaluation repo — even a
  // failing one must not block the 5 tabs.
  let accepted = BindFixtures.request(status: .accepted, skipEvaluation: true)
  let gate = makeEvaluationGate(
    request: accepted, evaluations: StubMyEvaluations(behavior: .failure))
  await gate.load()
  #expect(gate.state == .bound(accepted))
}
