import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Routing layer between authentication and the student 5-tab UI for
/// coached students (spec 031 §6; lives in StudentKit per D4 — AppShell only
/// wraps the `.coachedStudent` case). self-train students bypass the gate.
///
/// - `onboardingFlow`: 032's wizard slot. The completion callback reports
///   the bind handoff outcome so the gate lands on the contract state.
/// - `content`: the bound main UI (StudentRootView).
@available(iOS 17.0, macOS 14.0, *)
public struct BindGateView<
  MainContent: View, OnboardingContent: View, EvaluationContent: View
>: View {
  public typealias OnboardingFlowBuilder =
    (PendingBindCode, @escaping (BindHandoffOutcome) async -> Void) -> OnboardingContent
  /// 033's evaluation slot: the period plus a completion callback that
  /// reconverges the gate (→ 5 tabs).
  public typealias EvaluationFlowBuilder =
    (EvaluationPeriod, @escaping @MainActor () async -> Void) -> EvaluationContent

  @State private var viewModel: BindGateViewModel
  @Environment(\.scenePhase) private var scenePhase

  private let studentId: UUID
  private let bind: any BindRepository
  private let stash: any PendingBindCodeStoring
  private let isOnboardingComplete: @Sendable () async -> Bool
  private let onboardingProfile: @Sendable () async -> OnboardingProfile?
  private let onboardingFlow: OnboardingFlowBuilder
  private let evaluationFlow: EvaluationFlowBuilder
  private let content: () -> MainContent

  public init(
    studentId: UUID,
    bind: any BindRepository,
    stash: any PendingBindCodeStoring,
    evaluations: (any EvaluationRepository)? = nil,
    isOnboardingComplete: @escaping @Sendable () async -> Bool,
    onboardingProfile: @escaping @Sendable () async -> OnboardingProfile? = { nil },
    @ViewBuilder onboardingFlow: @escaping OnboardingFlowBuilder,
    @ViewBuilder evaluationFlow: @escaping EvaluationFlowBuilder,
    @ViewBuilder content: @escaping () -> MainContent
  ) {
    self.studentId = studentId
    self.bind = bind
    self.stash = stash
    self.isOnboardingComplete = isOnboardingComplete
    self.onboardingProfile = onboardingProfile
    self.onboardingFlow = onboardingFlow
    self.evaluationFlow = evaluationFlow
    self.content = content
    self._viewModel = State(
      initialValue: BindGateViewModel(
        studentId: studentId,
        bind: bind,
        stash: stash,
        isOnboardingComplete: isOnboardingComplete,
        evaluations: evaluations
      )
    )
  }

  public var body: some View {
    gateBody
      .task {
        if viewModel.state == .loading {
          await viewModel.load()
        }
      }
      .onChange(of: scenePhase) { _, newPhase in
        // Foreground return refreshes the waiting state (spec 031 D9).
        guard newPhase == .active else { return }
        if case .pendingAcceptance = viewModel.state {
          Task { await viewModel.refresh() }
        }
      }
  }

  @ViewBuilder
  private var gateBody: some View {
    switch viewModel.state {
    case .loading:
      // Full-screen spinner: never flash the enter-code page before an
      // accepted student lands in the 5 tabs (spec 031 risk 3).
      loadingView
    case .needsCode(let prefill, let notice):
      EnterCodeView(
        viewModel: EnterCodeViewModel(
          studentId: studentId,
          bind: bind,
          stash: stash,
          isOnboardingComplete: isOnboardingComplete,
          prefillDisplayName: prefill
        ),
        notice: notice
      ) { outcome in
        await viewModel.handleSubmitted(outcome)
      }
      .id(EnterCodeIdentity(prefill: prefill, notice: notice))
    case .needsOnboarding(let pending):
      onboardingFlow(pending) { outcome in
        await viewModel.handleHandoff(outcome)
      }
    case .pendingAcceptance(let request):
      PendingBindStateView(
        request: request,
        bind: bind,
        onboardingProfile: onboardingProfile,
        onCancelled: { viewModel.handleCancelled() },
        onStateMayHaveChanged: { await viewModel.refresh() }
      )
    case .evaluationActive(_, let evaluation):
      evaluationFlow(evaluation) {
        // Coach completed the evaluation → reconverge to .bound (5 tabs).
        await viewModel.load()
      }
    case .bound:
      content()
    case .failed:
      failedView
    }
  }

  private var loadingView: some View {
    VStack(spacing: MeetPRSpacing.md) {
      ProgressView()
      Text("正在检查绑定状态")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
  }

  private var failedView: some View {
    VStack(spacing: MeetPRSpacing.lg) {
      Image(systemName: "wifi.slash")
        .font(.system(size: 36))
        .foregroundStyle(Color.MeetPR.fgTertiary)
      Text("无法获取绑定状态")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      PrimaryButton("重试") {
        Task { await viewModel.load() }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bg)
  }
}

/// Forces EnterCodeView (and its @State view model) to rebuild when the gate
/// re-enters needsCode with a different prefill / notice.
private struct EnterCodeIdentity: Hashable {
  let prefill: String?
  let notice: BindNotice?
}

/// Wraps PendingBindView with the async materials lookup (separate type so
/// the gate body stays readable).
@available(iOS 17.0, macOS 14.0, *)
private struct PendingBindStateView: View {
  let request: BindRequest
  let bind: any BindRepository
  let onboardingProfile: @Sendable () async -> OnboardingProfile?
  let onCancelled: () -> Void
  let onStateMayHaveChanged: () async -> Void
  @State private var materials: PendingMaterialsSummary?

  var body: some View {
    PendingBindView(
      request: request,
      materialsSummary: materials,
      bind: bind,
      onCancelled: onCancelled,
      onStateMayHaveChanged: onStateMayHaveChanged
    )
    .task {
      materials = PendingMaterialsSummary.from(profile: await onboardingProfile())
    }
  }
}
