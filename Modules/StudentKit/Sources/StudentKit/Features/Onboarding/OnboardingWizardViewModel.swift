import Analytics
import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class OnboardingWizardViewModel {
  /// Post-complete handoff phase (spec 032 §6 transition page): only the
  /// network-failure branch needs interaction ([重试发送]).
  public enum Phase: Equatable, Sendable {
    case loading
    case editing
    /// Profile completed on the server; bind handoff running.
    case completing
    /// Handoff transport failure — stash kept, retry button shown. A cold
    /// start converges via BindGate's auto-resubmission.
    case handoffFailed
  }

  public private(set) var phase: Phase = .loading
  public private(set) var step = 1
  public var draft = OnboardingDraft()
  /// Non-blocking step-PUT failure banner (D6: the pre-complete full PUT is
  /// the catch-all, so a failed step save never blocks 下一步).
  public private(set) var saveBanner: String?
  public private(set) var isCompleting = false
  /// snake_case wire names from the 422 envelope; step views highlight
  /// their own fields (D12).
  public private(set) var highlightedFields: Set<String> = []
  public private(set) var usedDraftResume = false

  private let repo: any OnboardingRepository
  private let draftStore: LocalOnboardingDraftStore
  private let bind: any BindRepository
  private let stash: any PendingBindCodeStoring
  private let studentId: UUID
  private let onCompleted: (BindHandoffOutcome) async -> Void
  private let now: @Sendable () -> Date

  public init(
    studentId: UUID,
    repo: any OnboardingRepository,
    draftStore: LocalOnboardingDraftStore,
    bind: any BindRepository,
    stash: any PendingBindCodeStoring,
    onCompleted: @escaping (BindHandoffOutcome) async -> Void,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentId = studentId
    self.repo = repo
    self.draftStore = draftStore
    self.bind = bind
    self.stash = stash
    self.onCompleted = onCompleted
    self.now = now
  }

  public var isLastStep: Bool { step == OnboardingDraft.stepCount }

  public var canAdvance: Bool { draft.isStepComplete(step) }

  /// Server profile + local draft → merged working copy, resume at the
  /// first incomplete step (D6).
  public func load() async {
    phase = .loading
    var server: OnboardingProfile?
    if let fetched = try? await repo.fetchProfile(studentId: studentId) {
      server = fetched
    }
    // Already completed server-side (e.g. the gate's completion probe hit a
    // transient failure and routed here anyway): re-entering edit mode would
    // end in a fullPatch carrying locked 1RM fields → ONE_RM_LOCKED. Run the
    // handoff directly instead (Codex P1).
    if let server, server.completedAt != nil {
      await draftStore.clear(studentId: studentId)
      phase = .completing
      await runHandoff()
      return
    }
    let local = await draftStore.load(studentId: studentId)
    usedDraftResume = local != nil
    draft = OnboardingDraft.merged(server: server, local: local)
    step = draft.resumeStep
    phase = .editing
  }

  /// 下一步: gate on required fields, persist locally, best-effort PUT of
  /// the current step's fields (failure → banner, never blocks).
  public func advance() async {
    guard canAdvance, !isLastStep else { return }
    draft.furthestStep = max(draft.furthestStep, step + 1)
    await persistStep()
    step += 1
  }

  public func back() {
    guard step > 1 else { return }
    step -= 1
  }

  /// 保存并退出: local draft + best-effort PUT; the caller dismisses.
  public func saveAndExit() async {
    await persistStep()
  }

  /// 完成,开始训练! (spec 032 §6)
  public func complete() async {
    guard !isCompleting else { return }
    isCompleting = true
    defer { isCompleting = false }
    highlightedFields = []

    await saveDraftLocally()

    // 1. Catch-all full PUT (D6) — backfills anything a failed step PUT
    //    dropped. Unlike step PUTs this one must succeed before complete.
    do {
      _ = try await repo.upsert(draft.fullPatch())
    } catch OnboardingError.oneRMLocked {
      saveBanner = "1RM 已锁定,请联系教练修改"
      return
    } catch {
      saveBanner = "网络异常,资料未能提交,请重试"
      return
    }

    // 2. Server completion gate.
    do {
      _ = try await repo.complete()
    } catch OnboardingError.incomplete(let missingFields) {
      highlightedFields = Set(missingFields)
      if let field = Self.analyticsField(for: missingFields.first) {
        Analytics.shared.validationError(flow: .onboarding, field: field)
      }
      if let target = OnboardingDraft.earliestStep(forMissingFields: missingFields) {
        step = target
      }
      return
    } catch {
      saveBanner = "网络异常,请重试"
      return
    }

    await draftStore.clear(studentId: studentId)
    Analytics.shared.onboardingCompleted(
      filledStepCount: (1...OnboardingDraft.stepCount).filter { draft.isStepComplete($0) }.count,
      usedDraftResume: usedDraftResume)
    await runHandoff()
  }

  /// [重试发送] on the transition page.
  public func retryHandoff() async {
    await runHandoff()
  }

  // MARK: - Bind handoff (031↔032 contract, spec 032 §6 decision tree)

  private func runHandoff() async {
    phase = .completing
    guard let pending = stash.peek(studentId: studentId) else {
      // Reinstall / stash lost: gate reloads and lands on enter-code.
      await onCompleted(.needsReload)
      return
    }

    do {
      let request = try await bind.submitBindRequest(
        code: pending.code, displayName: pending.displayName)
      stash.clear(studentId: studentId)
      await onCompleted(.requestSent(request))
    } catch BindRequestError.invalidCode {
      // Onboarding stays completed server-side: re-entering a fresh code
      // resubmits immediately, never re-runs the wizard (031 D1).
      stash.clear(studentId: studentId)
      await onCompleted(.invalidCode(displayName: pending.displayName))
    } catch BindRequestError.alreadyPending, BindRequestError.alreadyBound {
      await onCompleted(.needsReload)
    } catch {
      phase = .handoffFailed
    }
  }

  // MARK: - Persistence helpers

  private func persistStep() async {
    await saveDraftLocally()
    do {
      _ = try await repo.upsert(draft.patch(forStep: step))
      saveBanner = nil
    } catch {
      saveBanner = "本步资料已暂存本机,提交完成时会自动补传"
    }
  }

  private func saveDraftLocally() async {
    draft.savedAt = now()
    try? await draftStore.save(draft, studentId: studentId)
  }

  private static func analyticsField(for wireName: String?) -> AnalyticsField? {
    guard let wireName else { return nil }
    if wireName.contains("weight") { return .bodyweight }
    if wireName.contains("competition") { return .competitionDate }
    if wireName.contains("goal") || wireName.contains("muscle") { return .goal }
    if wireName.contains("training") || wireName.contains("experience") { return .experience }
    return nil
  }
}
