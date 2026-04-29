import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct SignupView: View {
  @Environment(Session.self) private var session
  @State private var viewModel = AuthFormViewModel(mode: .signup)

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("SIGNUP")
          Text("注册账号")
            .font(Font.MeetPR.title1)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("选择一次身份后,V1 暂不支持切换")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        Card(accessibilityLabel: "注册表单") {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            MeetPRTextField(
              "手机号",
              text: $viewModel.phone,
              placeholder: "13800000001",
              helperText: "中国大陆 11 位手机号",
              errorMessage: viewModel.phoneError,
              isMonospaced: true
            )
            .accessibilityIdentifier("signup.phone")

            AuthSecureField(
              "密码",
              text: $viewModel.password,
              placeholder: "至少 8 字符",
              helperText: "最多 72 字节",
              errorMessage: viewModel.passwordError
            )
            .accessibilityIdentifier("signup.password")

            VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
              Text("我是")
                .font(Font.MeetPR.monoLabel)
                .tracking(Font.MeetPR.monoLabelTracking)
                .foregroundStyle(Color.MeetPR.fgTertiary)

              ForEach(UserRole.allCases, id: \.self) { role in
                RoleOptionButton(role: role, selectedRole: $viewModel.selectedRole)
              }
            }
            .accessibilityIdentifier("signup.role")

            if let toastMessage = viewModel.toastMessage {
              Text(toastMessage)
                .font(Font.MeetPR.footnote)
                .foregroundStyle(Color.MeetPR.brandRed)
                .accessibilityIdentifier("signup.toast")
            }

            PrimaryButton(
              "注册",
              isDisabled: !viewModel.canSubmit,
              isLoading: viewModel.isSubmitting,
              isFullWidth: true
            ) {
              Task {
                await viewModel.submit(using: session)
              }
            }
            .accessibilityIdentifier("signup.submit")
          }
        }
      }
      .padding(MeetPRSpacing.lg)
      .frame(maxWidth: 520, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("注册")
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct RoleOptionButton: View {
  let role: UserRole
  @Binding var selectedRole: UserRole?

  var body: some View {
    Button {
      selectedRole = role
    } label: {
      HStack(spacing: MeetPRSpacing.sm) {
        Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selectedRole == role ? Color.MeetPR.brandRed : Color.MeetPR.fgTertiary)

        Text(role.authTitle)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        Spacer()
      }
      .padding(MeetPRSpacing.md)
      .background(selectedRole == role ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface2)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(selectedRole == role ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("signup.role.\(role.rawValue)")
  }
}

extension UserRole {
  fileprivate var authTitle: String {
    switch self {
    case .coach:
      "教练"
    case .coachedStudent:
      "学员 (有教练)"
    case .selfTrainStudent:
      "学员 (自己练)"
    }
  }
}
