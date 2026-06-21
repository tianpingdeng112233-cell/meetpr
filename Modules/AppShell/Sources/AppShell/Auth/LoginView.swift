import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct LoginView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = AuthFormViewModel(mode: .login)

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          // ── Brand hero ───────────────────────────────────────────────
          MeetPRMark(size: 56)
            .padding(.bottom, MeetPRSpacing.lg)

          VStack(alignment: .leading, spacing: 0) {
            Text("Better")
              .font(.system(size: 92, weight: .black))
              .tracking(-3)
            Text("than yesterday")
              .font(.system(size: 46, weight: .black))
              .tracking(-1)
          }
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .fixedSize(horizontal: false, vertical: true)

          Rectangle()
            .fill(Color.MeetPR.brandRed)
            .frame(width: 48, height: 3)
            .padding(.top, MeetPRSpacing.base)

          Text("输入手机号和密码登录。")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .padding(.top, MeetPRSpacing.md)

          // ── Form (bare fields, mono labels — no card, matches kit) ───
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
          }
          .padding(.top, MeetPRSpacing.xl)

          Spacer(minLength: MeetPRSpacing.xl)

          // ── Actions ──────────────────────────────────────────────────
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

          appleSignInPlaceholder
            .padding(.top, MeetPRSpacing.md)
        }
        .padding(.horizontal, MeetPRSpacing.lg)
        .padding(.top, MeetPRSpacing.xl)
        .padding(.bottom, MeetPRSpacing.lg)
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(Color.MeetPR.bg)
    .hideNavigationBar()
  }

  // Apple Sign-In is deferred (V1.5+); shown as an inert, clearly-flagged placeholder.
  private var appleSignInPlaceholder: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Image(systemName: "apple.logo")
      Text("使用 Apple ID 登录")
        .font(Font.MeetPR.bodyEmphasis)
      Text("即将开放")
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .padding(.horizontal, MeetPRSpacing.xs)
        .padding(.vertical, 2)
        .background(Color.MeetPR.surface2)
        .clipShape(.rect(cornerRadius: MeetPRRadius.sm))
    }
    .foregroundStyle(Color.MeetPR.fgTertiary)
    .frame(maxWidth: .infinity)
    .frame(minHeight: 44)
    .padding(.vertical, 14)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .opacity(0.55)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("使用 Apple ID 登录，即将开放")
  }
}
