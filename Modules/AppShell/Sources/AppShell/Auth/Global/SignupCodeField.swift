import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct SignupCodeField: View {
  @Bindable var viewModel: GlobalRegisterViewModel
  let onSendCode: () async -> Void
  let onSignIn: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack {
        TextField(
          "", text: $viewModel.code,
          prompt: Text(text("auth.codePlaceholder")).foregroundStyle(Color.MeetPR.textDisabled)
        )
        .textFieldStyle(.plain)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
        .tracking(0)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .accessibilityLabel(text("auth.signupCode"))
        .accessibilityIdentifier("china.register.code")
        #if os(iOS)
          .keyboardType(.numberPad)
          .textContentType(.oneTimeCode)
        #endif
        .onChange(of: viewModel.code) { _, value in
          viewModel.code = String(GlobalAuthValidation.asciiDigits(from: value).prefix(6))
        }
        Button {
          Task { await onSendCode() }
        } label: {
          if viewModel.isSendingCode {
            ProgressView()
          } else {
            Text(
              viewModel.cooldownRemaining > 0
                ? text("auth.resendCountdown").replacing(
                  "{n}", with: String(viewModel.cooldownRemaining))
                : text(viewModel.sentEmail == nil ? "auth.getCode" : "auth.resend"))
          }
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(minHeight: 44)
        .disabled(!viewModel.canSendCode)
        .accessibilityIdentifier("china.register.sendCode")
      }
      .padding(MeetPRSpacing.point14)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.point14)
          .stroke(
            viewModel.codeError == nil ? Color.MeetPR.borderSubtle : Color.MeetPR.danger,
            lineWidth: MeetPRSpacing.point1)
      }
      if let error = viewModel.codeError {
        Text(error)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.danger)
          .accessibilityIdentifier("china.register.codeError")
      }
      if let sentEmail = viewModel.sentEmail, viewModel.codeError == nil {
        Text(text("auth.signupSent").replacing("{email}", with: sentEmail))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      if viewModel.sentEmail != nil {
        Text(helpText)
          .accessibilityIdentifier("china.register.signInHelp")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
          .environment(
            \.openURL,
            OpenURLAction { _ in
              onSignIn()
              return .handled
            })
      }
    }
  }

  private func text(_ key: String) -> String {
    EmailAuthStrings.text(key, track: .china)
  }

  private var helpText: AttributedString {
    var action = AttributedString(text("auth.signupHelpAction"))
    action[AttributeScopes.FoundationAttributes.LinkAttribute.self] = URL(
      string: "meetpr://sign-in")
    return AttributedString(text("auth.signupHelpPrefix")) + action
      + AttributedString(text("auth.signupHelpSuffix"))
  }
}
