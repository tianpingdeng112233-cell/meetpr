import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// 7-step onboarding wizard (spec 032 §4). Rendered through the BindGate's
/// `.needsOnboarding` slot: an interstitial ("继续填写") presents the wizard
/// full screen so 保存并退出 has somewhere to land.
@available(iOS 17.0, macOS 14.0, *)
public struct OnboardingWizardFlow: View {
  @State private var viewModel: OnboardingWizardViewModel
  @State private var isPresented = false

  public init(
    studentId: UUID,
    repo: any OnboardingRepository,
    draftStore: LocalOnboardingDraftStore,
    bind: any BindRepository,
    stash: any PendingBindCodeStoring,
    onCompleted: @escaping (BindHandoffOutcome) async -> Void
  ) {
    self._viewModel = State(
      initialValue: OnboardingWizardViewModel(
        studentId: studentId,
        repo: repo,
        draftStore: draftStore,
        bind: bind,
        stash: stash,
        onCompleted: onCompleted
      )
    )
  }

  public var body: some View {
    interstitial
      .onAppear { isPresented = true }
      #if os(iOS)
        .fullScreenCover(isPresented: $isPresented) {
          OnboardingWizardView(viewModel: viewModel)
        }
      #else
        .sheet(isPresented: $isPresented) {
          OnboardingWizardView(viewModel: viewModel)
        }
      #endif
  }

  private var interstitial: some View {
    VStack(spacing: MeetPRSpacing.lg) {
      Image(systemName: "list.clipboard")
        .font(.system(size: 40))
        .foregroundStyle(Color.MeetPR.gold500)
      Text("完成资料填写,教练才能开始评估")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size28))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .multilineTextAlignment(.center)
      Text("已填的内容都已保存,可随时继续")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textSecondary)
      GoldCTA("继续填写", sub: nil, icon: .none) {
        isPresented = true
      }
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct OnboardingWizardView: View {
  @Bindable var viewModel: OnboardingWizardViewModel
  @Environment(\.dismiss) private var dismiss

  private static let stepTitles = [
    "基础信息", "训练背景", "你的三大项极限是多少?", "训练环境", "恢复能力", "训练资料", "补充信息",
  ]

  var body: some View {
    NavigationStack {
      content
        // Wheel DatePickers (step 1 birthday, step 7 competition date) only
        // honor a locale inherited from an ancestor — setting it on the
        // picker itself leaves the wheel in the device language (iOS 26).
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .background(Color.MeetPR.bgBase)
        .navigationTitle("Step \(viewModel.step) of \(OnboardingDraft.stepCount)")
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("保存并退出") {
              Analytics.shared.navigationBack(from: .onboardingWizard, in: .onboarding)
              FrictionFeedbackController.shared.recordFlowCancel(
                flow: .onboarding, fromScreen: .onboardingWizard)
              Task {
                await viewModel.saveAndExit()
                dismiss()
              }
            }
            .disabled(viewModel.phase != .editing)
          }
        }
    }
    .task {
      if viewModel.phase == .loading {
        await viewModel.load()
      }
      Analytics.shared.screen(.onboardingWizard)
      trackCurrentStep()
    }
    .onChange(of: viewModel.step) { _, _ in trackCurrentStep() }
    .interactiveDismissDisabled()
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.phase {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .editing:
      editor
    case .completing, .handoffFailed:
      CompletionHandoffView(viewModel: viewModel)
    }
  }

  private var editor: some View {
    VStack(spacing: 0) {
      progressBar
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          Text(Self.stepTitles[viewModel.step - 1])
            .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
            .foregroundStyle(Color.MeetPR.textPrimary)

          stepBody

          if let banner = viewModel.saveBanner {
            Text(banner)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
              .foregroundStyle(Color.MeetPR.textSecondary)
              .padding(MeetPRSpacing.sm)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.MeetPR.surfaceElevated)
              .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
          }
        }
        .padding(MeetPRSpacing.base)
      }
      footerButtons
    }
  }

  @ViewBuilder
  private var stepBody: some View {
    switch viewModel.step {
    case 1:
      Step1BasicsSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    case 2:
      Step2BackgroundSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    case 3:
      Step3StrengthSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    case 4:
      Step4EnvironmentSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    case 5:
      Step5RecoverySection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    case 6:
      Step6MaterialsSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    default:
      Step7ExtrasSection(draft: $viewModel.draft, highlighted: viewModel.highlightedFields)
    }
  }

  private var progressBar: some View {
    GeometryReader { proxy in
      Rectangle()
        .fill(Color.MeetPR.surfaceElevated)
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(Color.MeetPR.gold500)
            .frame(
              width: proxy.size.width * CGFloat(viewModel.step)
                / CGFloat(OnboardingDraft.stepCount))
        }
    }
    .frame(height: 3)
  }

  private var footerButtons: some View {
    HStack(spacing: MeetPRSpacing.md) {
      if viewModel.step > 1 {
        SecondaryButton("上一步") {
          Analytics.shared.navigationBack(from: .onboardingWizard, in: .onboarding)
          viewModel.back()
        }
      }
      GoldCTA(
        viewModel.isLastStep ? "完成,开始训练!" : "下一步",
        sub: nil,
        icon: .none,
        isDisabled: !viewModel.canAdvance,
        isLoading: viewModel.isCompleting
      ) {
        Task {
          if viewModel.isLastStep {
            await viewModel.complete()
          } else {
            await viewModel.advance()
          }
        }
      }
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bgBase)
  }

  private func trackCurrentStep() {
    let names: [OnboardingStepName] = [
      .goal, .experience, .lifts, .schedule, .competition, .equipment, .review,
    ]
    guard names.indices.contains(viewModel.step - 1) else { return }
    Analytics.shared.onboardingStep(index: viewModel.step, name: names[viewModel.step - 1])
  }
}

/// "✓ 资料已提交" transition page (spec 032 §6): only the network-failure
/// branch needs interaction.
@available(iOS 17.0, macOS 14.0, *)
private struct CompletionHandoffView: View {
  @Bindable var viewModel: OnboardingWizardViewModel

  var body: some View {
    VStack(spacing: MeetPRSpacing.lg) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 44))
        .foregroundStyle(Color.MeetPR.success)
      Text("资料已提交")
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)

      if viewModel.phase == .handoffFailed {
        Text("绑定请求发送失败,请检查网络后重试")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.dangerMuted)
        GoldCTA("重试发送", sub: nil, icon: .none) {
          Task { await viewModel.retryHandoff() }
        }
      } else {
        ProgressView()
        Text("正在发送绑定请求")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
  }
}
