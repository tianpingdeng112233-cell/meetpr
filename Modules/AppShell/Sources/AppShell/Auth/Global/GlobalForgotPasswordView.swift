import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalForgotPasswordView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Session.self) private var environmentSession
  @State private var viewModel = GlobalForgotPasswordViewModel()

  private let sessionOverride: Session?
  private let onPasswordReset: () -> Void

  public init(onPasswordReset: @escaping () -> Void) {
    sessionOverride = nil
    self.onPasswordReset = onPasswordReset
  }

  init(
    viewModel: GlobalForgotPasswordViewModel,
    session: Session? = nil,
    onPasswordReset: @escaping () -> Void
  ) {
    _viewModel = State(initialValue: viewModel)
    sessionOverride = session
    self.onPasswordReset = onPasswordReset
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        GlobalAuthHero(title: "Reset your\npassword")

        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          if viewModel.step == .email {
            Text("Enter the email address linked to your account.")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)

            GlobalEmailField(
              "EMAIL",
              text: $viewModel.email,
              placeholder: "you@example.com",
              errorMessage: emailError
            )
            .accessibilityIdentifier("global.forgot.email")

            GlobalAuthButton(
              title: "Send code",
              isLoading: viewModel.isSubmitting,
              isDisabled: !viewModel.canSendCode
            ) {
              Task { await viewModel.sendCode(using: session) }
            }
            .accessibilityIdentifier("global.forgot.send")
          } else {
            Text("If an account exists, we've sent a code.")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textTertiary)

            TextField("6-digit code", text: $viewModel.code)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .semibold))
              .textFieldStyle(.plain)
              .padding(MeetPRSpacing.point14)
              .background(Color.MeetPR.surfaceCard)
              .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
              .overlay {
                RoundedRectangle(cornerRadius: MeetPRRadius.point14)
                  .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
              }
              #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
              #endif
              .onChange(of: viewModel.code) { _, newValue in
                viewModel.code = String(GlobalAuthValidation.asciiDigits(from: newValue).prefix(6))
              }
              .accessibilityIdentifier("global.forgot.code")

            AuthSecureField(
              "NEW PASSWORD",
              text: $viewModel.newPassword,
              placeholder: "At least 8 characters",
              helperText: "8–72 characters",
              errorMessage: passwordError
            )
            .accessibilityIdentifier("global.forgot.password")

            GlobalAuthButton(
              title: "Reset password",
              isLoading: viewModel.isSubmitting,
              isDisabled: !viewModel.canResetPassword
            ) {
              Task {
                if await viewModel.resetPassword(using: session) {
                  onPasswordReset()
                  dismiss()
                }
              }
            }
            .accessibilityIdentifier("global.forgot.reset")
          }

          if let toastMessage = viewModel.toastMessage {
            GlobalAuthToast(message: toastMessage)
              .accessibilityIdentifier("global.forgot.toast")
          }
        }
        .padding(.top, MeetPRSpacing.space6)
      }
      .padding(.horizontal, MeetPRSpacing.space6)
      .padding(.top, 44)
      .padding(.bottom, MeetPRSpacing.point26)
      .frame(maxWidth: 520, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background { GlobalAuthBackground() }
    .navigationTitle("Forgot password")
    .globalInlineNavigationTitle()
  }

  private var emailError: String? {
    guard !viewModel.email.isEmpty, !GlobalAuthValidation.isValidEmail(viewModel.email) else {
      return nil
    }
    return "Enter a valid email address"
  }

  private var session: Session {
    sessionOverride ?? environmentSession
  }

  private var passwordError: String? {
    guard
      !viewModel.newPassword.isEmpty,
      !GlobalAuthValidation.isValidPassword(viewModel.newPassword)
    else { return nil }
    return "Use 8–72 characters"
  }
}
