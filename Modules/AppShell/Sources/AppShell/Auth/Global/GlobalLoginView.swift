import AuthenticationServices
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalLoginView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = GlobalLoginViewModel()
  @State private var passwordResetMessage: String?

  public init() {}

  init(viewModel: GlobalLoginViewModel) {
    _viewModel = State(initialValue: viewModel)
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          GlobalAuthHero(title: "Better than\nyesterday")

          Spacer(minLength: MeetPRSpacing.space6)

          VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
            appleButton

            Button {
              Task { await viewModel.signInWithGoogle(using: session) }
            } label: {
              Label("Continue with Google", systemImage: "globe")
                .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
                .foregroundStyle(Color.MeetPR.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.MeetPR.surfaceCard)
                .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
                .overlay {
                  RoundedRectangle(cornerRadius: MeetPRRadius.point14)
                    .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("global.login.google")

            HStack(spacing: MeetPRSpacing.space3) {
              Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: MeetPRSpacing.point1)
              Text("or")
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
                .foregroundStyle(Color.MeetPR.textMuted)
              Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: MeetPRSpacing.point1)
            }

            GlobalEmailField(
              "EMAIL",
              text: $viewModel.email,
              placeholder: "you@example.com",
              errorMessage: emailError
            )
            .accessibilityIdentifier("global.login.email")

            AuthSecureField(
              "PASSWORD",
              text: $viewModel.password,
              errorMessage: passwordError
            )
            .accessibilityIdentifier("global.login.password")

            if let message = passwordResetMessage ?? viewModel.toastMessage {
              GlobalAuthToast(
                message: message,
                color: passwordResetMessage == nil ? Color.MeetPR.danger : Color.MeetPR.success
              )
              .accessibilityIdentifier("global.login.toast")
            }

            GlobalAuthButton(
              title: "Sign in",
              isLoading: viewModel.isSubmitting,
              isDisabled: !viewModel.canSubmitEmail
            ) {
              Task { await viewModel.signInWithEmail(using: session) }
            }
            .accessibilityIdentifier("global.login.submit")

            HStack {
              NavigationLink("Create account") {
                GlobalRegisterView()
              }
              Spacer()
              NavigationLink("Forgot password?") {
                GlobalForgotPasswordView {
                  passwordResetMessage = "Password updated, sign in with your new password"
                }
              }
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)

            HStack(spacing: MeetPRSpacing.space1) {
              Text("By continuing, you agree to our")
                .foregroundStyle(Color.MeetPR.textMuted)
              Link(
                "Privacy Policy",
                destination: URL(string: "https://meetpr.app/privacy/en")
                  ?? AnalyticsPrivacyNotice.privacyPolicyURL
              )
              .foregroundStyle(Color.MeetPR.goldText)
              .underline()
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, MeetPRSpacing.space6)
        .padding(.top, 44)
        .padding(.bottom, MeetPRSpacing.point26)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background { GlobalAuthBackground() }
    .hideNavigationBar()
    .task { await viewModel.prepareApple(using: session) }
  }

  private var appleButton: some View {
    SignInWithAppleButton(.continue) { request in
      request.requestedScopes = [.email]
      request.nonce = viewModel.appleNonceHash
    } onCompletion: { result in
      switch result {
      case .success(let authorization):
        guard
          let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
          let identityTokenData = credential.identityToken,
          let identityToken = String(data: identityTokenData, encoding: .utf8)
        else {
          viewModel.toastMessage = "We couldn't verify this sign-in. Please try again"
          return
        }
        let authorizationCode = credential.authorizationCode.flatMap {
          String(data: $0, encoding: .utf8)
        }
        Task {
          await viewModel.signInWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            using: session
          )
        }
      case .failure(let error):
        if let authorizationError = error as? ASAuthorizationError,
          authorizationError.code == .canceled
        {
          viewModel.toastMessage = nil
        } else {
          viewModel.toastMessage = GlobalAuthErrorMessage.message(for: error)
        }
      }
    }
    .signInWithAppleButtonStyle(.black)
    .frame(height: 52)
    .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
    .disabled(viewModel.appleNonceHash == nil || viewModel.isSubmitting)
    .opacity(viewModel.appleNonceHash == nil ? 0.55 : 1)
    .accessibilityIdentifier("global.login.apple")
  }

  private var emailError: String? {
    guard !viewModel.email.isEmpty, !GlobalAuthValidation.isValidEmail(viewModel.email) else {
      return nil
    }
    return "Enter a valid email address"
  }

  private var passwordError: String? {
    guard
      !viewModel.password.isEmpty,
      !GlobalAuthValidation.isValidPassword(viewModel.password)
    else { return nil }
    return "Use 8–72 characters"
  }
}
