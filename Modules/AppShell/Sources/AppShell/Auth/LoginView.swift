import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct LoginView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = AuthFormViewModel(mode: .login)

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("AUTH")
          Text("MeetPR")
            .font(Font.MeetPR.displayHero)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("登录后进入你的训练工作台")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        Card(accessibilityLabel: "登录表单") {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            MeetPRTextField(
              "手机号",
              text: $viewModel.phone,
              placeholder: "13800000001",
              helperText: "中国大陆 11 位手机号",
              errorMessage: viewModel.phoneError,
              isMonospaced: true
            )
            .accessibilityIdentifier("login.phone")

            AuthSecureField(
              "密码",
              text: $viewModel.password,
              placeholder: "password123",
              errorMessage: viewModel.passwordError
            )
            .accessibilityIdentifier("login.password")

            if let toastMessage = viewModel.toastMessage {
              Text(toastMessage)
                .font(Font.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.brandRed)
                .accessibilityIdentifier("login.toast")
            }

            PrimaryButton(
              "登录",
              isDisabled: !viewModel.canSubmit,
              isLoading: viewModel.isSubmitting,
              isFullWidth: true
            ) {
              Task {
                await viewModel.submit(using: session)
              }
            }
            .accessibilityIdentifier("login.submit")
          }
        }

        HStack(spacing: MeetPRSpacing.xs) {
          Text("没账号?")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)

          NavigationLink {
            SignupView()
          } label: {
            Text("注册")
              .font(Font.MeetPR.footnote)
              .bold()
              .foregroundStyle(Color.MeetPR.brandRed)
          }
          .accessibilityIdentifier("login.signup")
        }
        .frame(maxWidth: .infinity)
      }
      .padding(MeetPRSpacing.lg)
      .frame(maxWidth: 520, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("登录")
  }
}
