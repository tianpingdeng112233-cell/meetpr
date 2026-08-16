import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct GlobalRegisterView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = GlobalRegisterViewModel()

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        GlobalAuthHero(title: "Create your\naccount")

        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          Text("Join your coach and start building better training days.")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textTertiary)

          GlobalEmailField(
            "EMAIL",
            text: $viewModel.email,
            placeholder: "you@example.com",
            errorMessage: emailError
          )
          .accessibilityIdentifier("global.register.email")

          AuthSecureField(
            "PASSWORD",
            text: $viewModel.password,
            placeholder: "At least 8 characters",
            helperText: "8–72 characters",
            errorMessage: passwordError
          )
          .accessibilityIdentifier("global.register.password")

          if let toastMessage = viewModel.toastMessage {
            GlobalAuthToast(message: toastMessage)
              .accessibilityIdentifier("global.register.toast")
          }

          GlobalAuthButton(
            title: "Create account",
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
    .navigationTitle("Create account")
    .globalInlineNavigationTitle()
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
