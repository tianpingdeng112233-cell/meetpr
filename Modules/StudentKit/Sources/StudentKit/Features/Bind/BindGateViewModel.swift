import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Neutral notices shown atop the enter-code page (spec 031 D8: rejection is
/// never surfaced as rejection — wiki §3.4 silent semantics).
public enum BindNotice: Equatable, Sendable {
  /// Latest request was rejected — neutral copy, no "拒绝" wording.
  case coachNotAccepting
  /// Latest request lazily expired after 7 days.
  case requestExpired
  /// Stashed code turned out invalid at submit time.
  case invalidCode
  /// Auto-resubmission failed on transport; stash kept.
  case network

  public var message: String {
    switch self {
    case .coachNotAccepting:
      "教练当前不接收新学员,请输入新邀请码或稍后再试"
    case .requestExpired:
      "上次请求 7 天未响应已自动过期,可重新发送或换教练"
    case .invalidCode:
      "邀请码无效或已失效,请输入新邀请码"
    case .network:
      "网络异常,绑定请求暂未发出,可下拉重试"
    }
  }
}

public enum BindGateState: Equatable, Sendable {
  case loading
  case needsCode(prefillDisplayName: String?, notice: BindNotice?)
  /// → 032 wizard (rendered through the injected onboarding flow builder).
  case needsOnboarding(PendingBindCode)
  case pendingAcceptance(BindRequest)
  /// Accepted into a live evaluation period (skipEvaluation == false && the
  /// period is uncompleted) → the single-page EvaluationPeriodView replaces
  /// the 5 tabs (spec 033 §11, D6). Unreachable while
  /// `BindGateViewModel.evaluationSealed` is true (2026-07-13 beta seal).
  case evaluationActive(BindRequest, EvaluationPeriod)
  /// → 5-tab main content.
  case bound(BindRequest)
  /// `mine` fetch failed → full-screen retry. Never falls through to the
  /// 5 tabs: an unbound student in the main UI sees misleading empty plans
  /// (spec 031 risk 3).
  case failed
}

/// Result of 032's complete→bind handoff, reported back through the wizard's
/// onCompleted callback so the gate lands on the exact state the contract
/// table specifies (spec 031 §技术要求 / 032 §6) without a duplicate POST.
public enum BindHandoffOutcome: Equatable, Sendable {
  /// 201 — stash cleared, go straight to pending acceptance.
  case requestSent(BindRequest)
  /// INVITE_CODE_INVALID — stash cleared, back to enter-code with prefill.
  case invalidCode(displayName: String)
  /// already-pending / already-bound / no stash — reload `mine` to converge.
  case needsReload
}

@Observable
@MainActor
public final class BindGateViewModel {
  public private(set) var state: BindGateState = .loading

  private let bind: any BindRepository
  private let stash: any PendingBindCodeStoring
  private let isOnboardingComplete: @Sendable () async -> Bool
  private let studentId: UUID
  /// Evaluation routing source (spec 033 §11); nil keeps the pre-033
  /// behavior (accepted → straight to the 5 tabs).
  private let evaluations: (any EvaluationRepository)?

  public init(
    studentId: UUID,
    bind: any BindRepository,
    stash: any PendingBindCodeStoring,
    isOnboardingComplete: @escaping @Sendable () async -> Bool,
    evaluations: (any EvaluationRepository)? = nil
  ) {
    self.studentId = studentId
    self.bind = bind
    self.stash = stash
    self.isOnboardingComplete = isOnboardingComplete
    self.evaluations = evaluations
  }

  public func load() async {
    state = .loading
    let mine: BindRequest?
    do {
      mine = try await bind.myBindRequest()
    } catch {
      state = .failed
      return
    }

    switch mine?.status {
    case .accepted:
      if let mine { state = await boundState(for: mine) }
    case .pending:
      if let mine { state = .pendingAcceptance(mine) }
    case .none, .rejected, .expired, .cancelled:
      await resolveUnbound(latest: mine)
    }
  }

  /// 2026-07-13 (David): the evaluation period is sealed for beta — accepted
  /// students route straight to the 5 tabs even when a legacy uncompleted
  /// period exists (defer ≠ delete; spec 033 code stays dormant). Flip to
  /// false to restore the spec 033 §11 evaluation sub-route below.
  private static let evaluationSealed = true

  /// Accepted → `.bound` while sealed (above). Unsealed behavior
  /// (spec 033 §11): a live (uncompleted) evaluation period shows the
  /// single-page state; no period / completed → the 5 tabs. A fetch failure
  /// must NOT fold into `.bound` — that would let an in-evaluation student
  /// through to the 5 tabs on a network blip (Codex review P1) — so it
  /// lands on the full-screen retry like the `mine` fetch above.
  private func boundState(for request: BindRequest) async -> BindGateState {
    if Self.evaluationSealed {
      return .bound(request)
    }
    guard !request.skipEvaluation, let evaluations else {
      return .bound(request)
    }
    let evaluation: EvaluationPeriod?
    do {
      evaluation = try await evaluations.fetchMyEvaluation()
    } catch {
      return .failed
    }
    guard let evaluation, evaluation.completedAt == nil else {
      return .bound(request)
    }
    return .evaluationActive(request, evaluation)
  }

  /// Soft refresh for the pending page (pull-to-refresh / scenePhase): only
  /// reloads when the gate is already past `.loading`.
  public func refresh() async {
    guard state != .loading else { return }
    await load()
  }

  // MARK: - Enter-code page callbacks

  public func handleSubmitted(_ outcome: EnterCodeViewModel.SubmitOutcome) async {
    switch outcome {
    case .requestSent(let request):
      // A 201 ends any stash lifecycle: a stale code left by an earlier
      // transport failure must never ghost-resubmit later (Codex P1).
      await stash.clear(studentId: studentId)
      state = .pendingAcceptance(request)
    case .stashedForOnboarding(let pending):
      state = .needsOnboarding(pending)
    case .needsReload:
      await load()
    }
  }

  // MARK: - Wizard handoff callback (032 → 031 contract)

  public func handleHandoff(_ outcome: BindHandoffOutcome) async {
    switch outcome {
    case .requestSent(let request):
      state = .pendingAcceptance(request)
    case .invalidCode(let displayName):
      state = .needsCode(prefillDisplayName: displayName, notice: .invalidCode)
    case .needsReload:
      await load()
    }
  }

  // MARK: - Pending page callbacks

  public func handleCancelled() {
    stash.clear(studentId: studentId)
    state = .needsCode(prefillDisplayName: nil, notice: nil)
  }

  // MARK: - Unbound resolution (cold-start resume included, spec 031 §6)

  private func resolveUnbound(latest: BindRequest?) async {
    guard let pending = stash.peek(studentId: studentId) else {
      state = .needsCode(prefillDisplayName: nil, notice: Self.notice(for: latest?.status))
      return
    }

    guard await isOnboardingComplete() else {
      state = .needsOnboarding(pending)
      return
    }

    // Stash + onboarding complete → auto-resubmit (the 032 handoff's
    // network-failure retry path).
    do {
      let request = try await bind.submitBindRequest(
        code: pending.code, displayName: pending.displayName)
      stash.clear(studentId: studentId)
      state = .pendingAcceptance(request)
    } catch BindRequestError.invalidCode {
      stash.clear(studentId: studentId)
      state = .needsCode(prefillDisplayName: pending.displayName, notice: .invalidCode)
    } catch BindRequestError.alreadyPending, BindRequestError.alreadyBound {
      // Server already advanced; one re-read converges. The stash survives,
      // but the next resolveUnbound only runs after the bond dissolves —
      // and an invalid stale code then resolves through `.invalidCode`.
      await reloadAfterConflict()
    } catch {
      // Transport failure: keep the stash, surface a neutral notice; the
      // next load retries automatically.
      state = .needsCode(prefillDisplayName: pending.displayName, notice: .network)
    }
  }

  /// One non-recursive re-read after already-pending / already-bound: maps
  /// the now-authoritative server state directly (avoids load() → resolve →
  /// submit ping-pong).
  private func reloadAfterConflict() async {
    let mine: BindRequest?
    do {
      mine = try await bind.myBindRequest()
    } catch {
      state = .failed
      return
    }

    switch mine?.status {
    case .accepted:
      if let mine {
        stash.clear(studentId: studentId)
        state = await boundState(for: mine)
      }
    case .pending:
      if let mine {
        stash.clear(studentId: studentId)
        state = .pendingAcceptance(mine)
      }
    case .none, .rejected, .expired, .cancelled:
      state = .needsCode(prefillDisplayName: nil, notice: Self.notice(for: mine?.status))
    }
  }

  /// D8 mapping: rejected → neutral "not accepting"; expired → expired copy;
  /// cancelled / no history → no notice.
  private static func notice(for status: BindRequestStatus?) -> BindNotice? {
    switch status {
    case .rejected: .coachNotAccepting
    case .expired: .requestExpired
    case .pending, .accepted, .cancelled, .none: nil
    }
  }
}
