import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Solo 轻 onboarding (spec 046 §2): ≤2 screens, zero coach/plan/template
/// words. Screen 1 confirms the unit (kg default) with an optional bodyweight;
/// screen 2 is the skippable big-3 baseline.
@available(iOS 17.0, macOS 14.0, *)
public struct SoloOnboardingFlow: View {
  @State private var viewModel: SoloOnboardingViewModel

  public init(
    repository: any OnboardingRepository,
    onCompleted: @escaping @MainActor () -> Void
  ) {
    self._viewModel = State(
      initialValue: SoloOnboardingViewModel(repository: repository, onCompleted: onCompleted))
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          if viewModel.step == .unit {
            unitScreen
          } else {
            baselineScreen
          }
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle(viewModel.step == .unit ? "先定个单位" : "入门基线")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }

  @ViewBuilder
  private var unitScreen: some View {
    Text("记录重量用什么单位?之后随时可改。")
      .font(Font.MeetPR.caption)
      .foregroundStyle(Color.MeetPR.fgSecondary)

    Picker("单位", selection: $viewModel.unitPreference) {
      Text("kg").tag(UnitPreference.kg)
      Text("lb").tag(UnitPreference.lb)
    }
    .pickerStyle(.segmented)

    OnboardingNumberField(
      title: "体重(可选)",
      unitSuffix: UnitDisplay.weightUnitSuffix(viewModel.unitPreference),
      text: $viewModel.weightText,
      onCommit: { _ in },
      placeholder: "75"
    )

    PrimaryButton("继续", isFullWidth: true) {
      viewModel.advanceToBaseline()
    }
    .accessibilityIdentifier("solo.onboarding.continue")
  }

  @ViewBuilder
  private var baselineScreen: some View {
    Text("填上三大项 1RM,成长曲线从第一天就有锚点。")
      .font(Font.MeetPR.caption)
      .foregroundStyle(Color.MeetPR.fgSecondary)

    // Solo has no coach: the coached lock warning stays off (spec 013).
    Step3StrengthSection(draft: $viewModel.draft, lockWarning: nil)

    Text("不确定?先跳过,练几次成长页自然有走势。")
      .font(Font.MeetPR.caption)
      .foregroundStyle(Color.MeetPR.fgTertiary)

    if case .failed(let message) = viewModel.state {
      Label(message, systemImage: "exclamationmark.triangle")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.brandRed)
    }

    PrimaryButton(
      viewModel.state == .submitting ? "保存中…" : "开始训练",
      isFullWidth: true
    ) {
      Task { await viewModel.finish(skippingBaseline: false) }
    }
    .accessibilityIdentifier("solo.onboarding.finish")

    Button("先跳过") {
      Task { await viewModel.finish(skippingBaseline: true) }
    }
    .font(Font.MeetPR.bodyEmphasis)
    .foregroundStyle(Color.MeetPR.fgSecondary)
    .frame(maxWidth: .infinity)
    .accessibilityIdentifier("solo.onboarding.skip")
  }
}
