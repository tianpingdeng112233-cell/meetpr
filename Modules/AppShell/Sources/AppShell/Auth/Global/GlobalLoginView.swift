import AuthenticationServices
import DesignSystem
import Networking
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalLoginView: View {
  @Environment(Session.self) private var session
  @Environment(\.colorScheme) private var colorScheme
  @State private var viewModel: GlobalLoginViewModel
  private let buildTrack: MeetPRBuildTrack
  @State private var passwordResetMessage: String?

  public init(buildTrack: MeetPRBuildTrack = .global) {
    self.buildTrack = buildTrack
    _viewModel = State(initialValue: GlobalLoginViewModel(buildTrack: buildTrack))
  }

  init(viewModel: GlobalLoginViewModel) {
    buildTrack = viewModel.buildTrack
    _viewModel = State(initialValue: viewModel)
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          GlobalAuthHero(
            title: text(buildTrack == .china ? "auth.chinaSlogan" : "auth.globalSlogan"))

          Spacer(minLength: MeetPRSpacing.space6)

          VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
            GlobalEmailField(
              text("auth.email"),
              text: $viewModel.email,
              placeholder: text("auth.emailPlaceholder"),
              errorMessage: emailError,
              usesEmailTypography: buildTrack == .china
            )
            .accessibilityIdentifier("global.login.email")

            AuthSecureField(
              text("auth.password"),
              text: $viewModel.password,
              errorMessage: passwordError,
              usesEmailTypography: buildTrack == .china
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
              title: text("auth.signIn"),
              isLoading: viewModel.isSubmitting,
              isDisabled: !viewModel.canSubmitEmail
            ) {
              Task { await viewModel.signInWithEmail(using: session) }
            }
            .accessibilityIdentifier("global.login.submit")

            HStack {
              NavigationLink(text("auth.createAccount")) {
                GlobalRegisterView(buildTrack: buildTrack)
              }
              Spacer()
              NavigationLink(text("auth.forgotLink")) {
                GlobalForgotPasswordView(buildTrack: buildTrack) {
                  passwordResetMessage = text("auth.passwordUpdated")
                }
              }
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.goldText)

            if buildTrack == .global {
              HStack(spacing: MeetPRSpacing.space3) {
                Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: MeetPRSpacing.point1)
                Text(text("auth.or"))
                  .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
                  .foregroundStyle(Color.MeetPR.textMuted)
                Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: MeetPRSpacing.point1)
              }

              appleButton

              Button {
                Task { await viewModel.signInWithGoogle(using: session) }
              } label: {
                Label(text("auth.google"), systemImage: "globe")
                  .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
                  .foregroundStyle(Color.MeetPR.textPrimary)
                  .frame(maxWidth: .infinity)
                  .frame(height: MeetPRSpacing.point52)
                  .background(Color.MeetPR.surfaceCard)
                  .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
                  .overlay {
                    RoundedRectangle(cornerRadius: MeetPRRadius.point14)
                      .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
                  }
              }
              .disabled(viewModel.isSubmitting)
              .accessibilityIdentifier("global.login.google")

            }

            HStack(spacing: MeetPRSpacing.space1) {
              Text(text("auth.consent"))
                .foregroundStyle(Color.MeetPR.textMuted)
              Link(
                text("auth.privacy"),
                destination: URL(
                  string: buildTrack == .china
                    ? "https://meetpr.app/privacy/zh" : "https://meetpr.app/privacy/en")
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
    .task { if buildTrack == .global { await viewModel.prepareApple(using: session) } }
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
          viewModel.toastMessage = text("auth.invalidIdentityToken")
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
    .signInWithAppleButtonStyle(colorScheme == .dark ? .black : .whiteOutline)
    .frame(maxWidth: .infinity)
    .frame(height: MeetPRSpacing.point52)
    .clipShape(.rect(cornerRadius: MeetPRRadius.point14))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.point14)
        .stroke(Color.MeetPR.borderSubtle, lineWidth: MeetPRSpacing.point1)
    }
    .disabled(viewModel.appleNonceHash == nil || viewModel.isSubmitting)
    .opacity(viewModel.appleNonceHash == nil ? 0.55 : 1)
    .accessibilityIdentifier("global.login.apple")
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
