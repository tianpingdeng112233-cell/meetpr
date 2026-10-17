import DesignSystem
import Networking
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalForgotPasswordView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Session.self) private var environmentSession
  @State private var viewModel: GlobalForgotPasswordViewModel
  private let buildTrack: MeetPRBuildTrack

  private let sessionOverride: Session?
  private let onPasswordReset: () -> Void

  public init(buildTrack: MeetPRBuildTrack = .global, onPasswordReset: @escaping () -> Void) {
    self.buildTrack = buildTrack
    _viewModel = State(initialValue: GlobalForgotPasswordViewModel(buildTrack: buildTrack))
    sessionOverride = nil
    self.onPasswordReset = onPasswordReset
  }

  init(
    viewModel: GlobalForgotPasswordViewModel,
    session: Session? = nil,
    onPasswordReset: @escaping () -> Void
  ) {
    buildTrack = viewModel.buildTrack
    _viewModel = State(initialValue: viewModel)
    sessionOverride = session
    self.onPasswordReset = onPasswordReset
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        GlobalAuthHero(
          title: text(viewModel.step == .email ? "auth.forgotTitle" : "auth.resetTitle"))

        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          if viewModel.step == .email {
            Text(text("auth.forgotSubtitle"))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)

            GlobalEmailField(
              text("auth.email"),
              text: $viewModel.email,
              placeholder: text("auth.emailPlaceholder"),
              errorMessage: emailError,
              usesEmailTypography: buildTrack == .china
            )
            .accessibilityIdentifier("global.forgot.email")

            GlobalAuthButton(
              title: text("auth.sendCode"),
              isLoading: viewModel.isSubmitting,
              isDisabled: !viewModel.canSendCode
            ) {
              Task { await viewModel.sendCode(using: session) }
            }
            .accessibilityIdentifier("global.forgot.send")
          } else {
            Text(text("auth.resetSent"))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textTertiary)

            TextField(
              "", text: $viewModel.code,
              prompt: Text(text("auth.codePlaceholder")).foregroundStyle(
                buildTrack == .china ? Color.MeetPR.textDisabled : Color.secondary)
            )
            .font(
              buildTrack == .china
                ? .MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold)
                : .MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .semibold)
            )
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
              text("auth.newPassword"),
              text: $viewModel.newPassword,
              placeholder: text("auth.newPasswordPlaceholder"),
              helperText: text("auth.passwordHelper"),
              errorMessage: passwordError,
              usesEmailTypography: buildTrack == .china
            )
            .accessibilityIdentifier("global.forgot.password")

            GlobalAuthButton(
              title: text("auth.resetButton"),
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
    .navigationTitle(text("auth.forgotHeader"))
    .globalInlineNavigationTitle()
  }

  private var emailError: String? {
    guard !viewModel.email.isEmpty, !GlobalAuthValidation.isValidEmail(viewModel.email) else {
      return nil
    }
    return text("auth.invalidEmail")
  }

  private var session: Session {
    sessionOverride ?? environmentSession
  }

  private var passwordError: String? {
    guard
      !viewModel.newPassword.isEmpty,
      !GlobalAuthValidation.isValidPassword(viewModel.newPassword)
    else { return nil }
    return text("auth.invalidPassword")
  }
  private func text(_ key: String) -> String {
    EmailAuthStrings.text(key, track: buildTrack)
  }

}
