import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Enter-code page (spec 031 §5): first screen after a coached-student
/// registration. Collects the invite code + the student's display name; the
/// submit outcome routes through the BindGate.
///
/// Visual language follows the 4b screen of David's 2026-07-30 light mockup;
/// the mechanics (10-char code, required display name, submit = *request* that
/// the coach must accept) are unchanged — see `docs/design/login-v3/CARD-bind.md`
/// §有意偏离设计稿 for every place this deliberately departs from the drawing.
@available(iOS 17.0, macOS 14.0, *)
struct EnterCodeView: View {
  @State private var viewModel: EnterCodeViewModel
  @State private var pasteError: String?
  @State private var dismissesFieldError = false
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
      VStack(alignment: .leading, spacing: MeetPRSpacing.space6) {
        if let notice {
          BindNoticeBanner(notice: notice)
        }

        BindEnterCodeHeader()

        InviteCodeEntry(
          code: codeBinding,
          errorMessage: displayedFieldError?.message,
          pasteError: pasteError,
          onPaste: pasteInviteCode
        )

        BindInstructionsCard()

        MeetPRTextField(
          "你的姓名",
          text: $viewModel.displayName,
          placeholder: "填你自己的名字",
          helperText: "教练会在学员列表里看到这个名字"
        )

        if viewModel.showsNetworkBanner {
          Label("网络异常,请重试", systemImage: "wifi.exclamationmark")
            .font(Font.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .medium))
            .foregroundStyle(Color.MeetPR.dangerMuted)
        }

        // The submit CTA is always the real one. An invalid-code error only
        // *adds* 清空重输 beside it — the code stays in the boxes (card §错误态)
        // and stays submittable, so a student whose coach just regenerated the
        // code can retry without first having to mangle a character.
        HStack(spacing: MeetPRSpacing.space3) {
          if displayedFieldError != nil {
            BindClearCodeButton(action: clearInviteCode)
          }

          BindSubmitCTA(
            isDisabled: !viewModel.isSubmittable,
            isLoading: viewModel.isSubmitting,
            action: submit
          )
        }
      }
      .padding(.horizontal, MeetPRSpacing.space6)
      // Clears the gate's top-trailing 登出 affordance (BindGateView).
      .padding(.top, MeetPRSpacing.point64)
      .padding(.bottom, MeetPRSpacing.point32)
    }
    .scrollIndicators(.hidden)
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .onAppear {
      Analytics.shared.screen(.bindEnterCode)
      Analytics.shared.bindCoachAction(.inviteOpen)
    }
  }

  /// The server-side error is cleared optimistically as soon as the student
  /// edits the code, so the red boxes do not outlive the input they judged.
  private var displayedFieldError: EnterCodeViewModel.FieldError? {
    dismissesFieldError ? nil : viewModel.fieldError
  }

  private var codeBinding: Binding<String> {
    Binding(
      get: { viewModel.codeInput },
      set: { newValue in
        viewModel.codeInput = Self.sanitized(newValue)
        dismissesFieldError = true
        pasteError = nil
      }
    )
  }

  /// Uppercase, drop separators, drop anything outside the locked alphabet
  /// (so an `O` or `0` never lands in a box that can never validate), then cap
  /// at the code length.
  static func sanitized(_ raw: String) -> String {
    let normalized = InviteCodeFormat.normalize(raw)
      .filter { InviteCodeFormat.alphabet.contains($0) }
    return String(normalized.prefix(InviteCodeFormat.length))
  }

  private func pasteInviteCode() {
    #if os(iOS)
      let pastedCode = InviteCodePaste.validCode(from: UIPasteboard.general.string)
    #else
      let pastedCode: String? = nil
    #endif

    guard let pastedCode else {
      pasteError = "剪贴板里没有有效的 \(InviteCodeFormat.length) 位邀请码"
      return
    }

    viewModel.codeInput = pastedCode
    dismissesFieldError = true
    pasteError = nil
  }

  private func clearInviteCode() {
    viewModel.codeInput = ""
    dismissesFieldError = true
    pasteError = nil
  }

  private func submit() {
    dismissesFieldError = false
    Task {
      if let outcome = await viewModel.submit() {
        await onSubmitted(outcome)
      }
    }
  }
}

enum InviteCodePaste {
  static func validCode(from clipboardText: String?) -> String? {
    guard let clipboardText else { return nil }
    let normalized = InviteCodeFormat.normalize(clipboardText)
    return InviteCodeFormat.isValid(normalized) ? normalized : nil
  }
}
