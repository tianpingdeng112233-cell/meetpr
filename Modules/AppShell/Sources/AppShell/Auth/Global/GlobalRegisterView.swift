import DesignSystem
import Networking
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalRegisterView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Session.self) private var session
  @State private var viewModel: GlobalRegisterViewModel
  private let buildTrack: MeetPRBuildTrack

  public init(buildTrack: MeetPRBuildTrack = .global) {
    self.buildTrack = buildTrack
    _viewModel = State(initialValue: GlobalRegisterViewModel(buildTrack: buildTrack))
  }

  init(viewModel: GlobalRegisterViewModel) {
    buildTrack = viewModel.buildTrack
    _viewModel = State(initialValue: viewModel)
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    AuthFormScrollView {
      VStack(alignment: .leading, spacing: 0) {
        GlobalAuthHero(title: text("auth.registerTitle"))

        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          Text(text("auth.registerSubtitle"))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textTertiary)

          GlobalEmailField(
            text("auth.email"),
            text: $viewModel.email,
            placeholder: text("auth.emailPlaceholder"),
            errorMessage: emailError,
            usesEmailTypography: buildTrack == .china
          )
          .authScrollTarget("global.register.email")
          .disabled(buildTrack == .china && viewModel.isSubmitting)

          if buildTrack == .china {
            SignupCodeField(
              viewModel: viewModel,
              onSendCode: {
                await viewModel.sendCode(using: session)
              }, onSignIn: { dismiss() }
            )
            .authScrollTarget("china.register.code")
            .disabled(buildTrack == .china && viewModel.isSubmitting)
          }

          AuthSecureField(
            text("auth.password"),
            text: $viewModel.password,
            placeholder: text("auth.passwordPlaceholder"),
            helperText: text("auth.passwordHelper"),
            errorMessage: passwordError,
            usesEmailTypography: buildTrack == .china
          )
          .authScrollTarget("global.register.password")
          .disabled(buildTrack == .china && viewModel.isSubmitting)

          if buildTrack == .china {
            AuthSecureField(
              text("auth.confirmPassword"), text: $viewModel.confirmPassword,
              placeholder: text("auth.confirmPlaceholder"),
              errorMessage: viewModel.confirmPassword.isEmpty
                || viewModel.confirmPassword == viewModel.password
                ? nil : text("auth.passwordMismatch"),
              usesEmailTypography: true
            )
            .authScrollTarget("china.register.confirmPassword")
            .disabled(buildTrack == .china && viewModel.isSubmitting)
          }

          if let toastMessage = viewModel.toastMessage {
            GlobalAuthToast(message: toastMessage)
              .accessibilityIdentifier("global.register.toast")
          }

          if viewModel.shouldOfferSignIn {
            Button(text("auth.goSignIn")) { dismiss() }
              .disabled(buildTrack == .china && viewModel.isSubmitting)
              .accessibilityIdentifier("china.register.signIn")
          }

          GlobalAuthButton(
            title: text("auth.registerButton"),
            isLoading: viewModel.isSubmitting,
            isDisabled: !viewModel.canSubmit
          ) {
            Task { await viewModel.submit(using: session) }
          }
          .accessibilityIdentifier("global.register.submit")
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
    .navigationTitle(text("auth.createAccount"))
    .globalInlineNavigationTitle()
    .task {
      guard buildTrack == .china else { return }
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        viewModel.tickCooldown()
      }
    }
  }

  private var emailError: String? {
    guard !viewModel.email.isEmpty, !GlobalAuthValidation.isValidEmail(viewModel.email) else {
      return nil
    }
    return text("auth.invalidEmail")
  }

  private var passwordError: String? {
    guard
      !viewModel.password.isEmpty,
      !GlobalAuthValidation.isValidPassword(viewModel.password)
    else { return nil }
    return text("auth.invalidPassword")
  }
  private func text(_ key: String) -> String {
    EmailAuthStrings.text(key, track: buildTrack)
  }

}
