import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Enter-code page (spec 031 §5): first screen after a coached-student
/// registration. Collects the invite code + the student's display name; the
/// submit outcome routes through the BindGate.
@available(iOS 17.0, macOS 14.0, *)
struct EnterCodeView: View {
  @State private var viewModel: EnterCodeViewModel
  private let notice: BindNotice?
  private let onSubmitted: (EnterCodeViewModel.SubmitOutcome) async -> Void

  init(
    viewModel: EnterCodeViewModel,
    notice: BindNotice?,
    onSubmitted: @escaping (EnterCodeViewModel.SubmitOutcome) async -> Void
  ) {
    self._viewModel = State(initialValue: viewModel)
    self.notice = notice
    self.onSubmitted = onSubmitted
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        if let notice {
          noticeBanner(notice)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text("输入教练邀请码")
            .font(Font.MeetPR.title1)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("没有教练?请向你的教练索取邀请码")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }

        codeField

        MeetPRTextField(
          "你的姓名",
          text: $viewModel.displayName,
          placeholder: "填你自己的名字",
          helperText: "教练会在学员列表里看到这个名字"
        )

        if viewModel.showsNetworkBanner {
          Text("网络异常,请重试")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.gold500)
        }

        BrandPrimaryButton(
          "提交",
          showsShimmer: true,
          isDisabled: !viewModel.isSubmittable,
          isLoading: viewModel.isSubmitting,
          isFullWidth: true
        ) {
          Task {
            if let outcome = await viewModel.submit() {
              await onSubmitted(outcome)
            }
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .onAppear {
      Analytics.shared.screen(.bindEnterCode)
      Analytics.shared.bindCoachAction(.inviteOpen)
    }
  }

  private var codeField: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      MeetPRTextField(
        "邀请码",
        text: $viewModel.codeInput,
        placeholder: "XXXXXXXXXX",
        helperText: viewModel.codeFormatHint,
        errorMessage: viewModel.fieldError?.message,
        isMonospaced: true
      )
      #if os(iOS)
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      #endif

      if let grouped = viewModel.groupedCodePreview {
        Text(grouped)
          .font(Font.MeetPR.monoLabel)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
  }

  private func noticeBanner(_ notice: BindNotice) -> some View {
    Text(notice.message)
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(MeetPRSpacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceElevated)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }
}
