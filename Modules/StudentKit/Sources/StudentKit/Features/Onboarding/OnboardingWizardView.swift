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
        .foregroundStyle(Color.MeetPR.fgTertiary)
      Text("完成资料填写,教练才能开始评估")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .multilineTextAlignment(.center)
      Text("已填的内容都已保存,可随时继续")
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      PrimaryButton("继续填写", isFullWidth: true) {
        isPresented = true
      }
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
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
        .background(Color.MeetPR.bg)
        .navigationTitle("Step \(viewModel.step) of \(OnboardingDraft.stepCount)")
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("保存并退出") {
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
    }
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
            .font(Font.MeetPR.title1)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          stepBody

          if let banner = viewModel.saveBanner {
            Text(banner)
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
              .padding(MeetPRSpacing.sm)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.MeetPR.surface2)
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
        .fill(Color.MeetPR.surface2)
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(Color.MeetPR.brandRed)
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
          viewModel.back()
        }
      }
      PrimaryButton(
        viewModel.isLastStep ? "完成,开始训练!" : "下一步",
        isDisabled: !viewModel.canAdvance,
        isLoading: viewModel.isCompleting,
        isFullWidth: true
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
    .background(Color.MeetPR.bg)
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
        .foregroundStyle(Color.MeetPR.brandRed)
      Text("资料已提交")
        .font(Font.MeetPR.title1)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      if viewModel.phase == .handoffFailed {
        Text("绑定请求发送失败,请检查网络后重试")
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        PrimaryButton("重试发送", isFullWidth: true) {
          Task { await viewModel.retryHandoff() }
        }
      } else {
        ProgressView()
        Text("正在发送绑定请求")
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
  }
}
