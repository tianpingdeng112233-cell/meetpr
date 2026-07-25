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
      VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
        // ── Brand hero ───────────────────────────────────────────────
        MeetPRMark(size: 56)
          .padding(.bottom, MeetPRSpacing.lg)

        Eyebrow("注册 · 角色")
        Text("选择你的角色")
          .font(.MeetPR.display(size: 40, weight: .extraBold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.top, MeetPRSpacing.space2)
        (Text("注册后角色将锁定。").foregroundStyle(Color.MeetPR.textSecondary)
          + Text("多角色支持在 V1.5 评估。").foregroundStyle(Color.MeetPR.textTertiary))
          .font(.MeetPR.system(size: MeetPRFontMetrics.size40, weight: .heavy))
          .padding(.top, MeetPRSpacing.space3)

        // ── Credentials ──────────────────────────────────────────────
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
        }
        .padding(.top, MeetPRSpacing.xl)

        // ── Role cards (design `AuthFlow` step 1, big cards) ──────────
        VStack(spacing: MeetPRSpacing.space3) {
          ForEach(UserRole.allCases, id: \.self) { role in
            RoleCard(role: role, selectedRole: $viewModel.selectedRole)
          }
        }
        .accessibilityIdentifier("signup.role")
        .padding(.top, MeetPRSpacing.point26)

        if let toastMessage = viewModel.toastMessage {
          Text(toastMessage)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.gold500)
            .accessibilityIdentifier("signup.toast")
            .padding(.top, MeetPRSpacing.md)
        }

        // ── Submit ───────────────────────────────────────────────────
        BrandPrimaryButton(
          "注册",
          showsShimmer: true,
          isDisabled: !viewModel.canSubmit,
          isLoading: viewModel.isSubmitting,
          isFullWidth: true
        ) {
          Task {
            await viewModel.submit(using: session)
          }
        }
        .accessibilityIdentifier("signup.submit")
        .padding(.top, MeetPRSpacing.point26)
      }
      .padding(.horizontal, MeetPRSpacing.space6)
      .padding(.top, MeetPRSpacing.point32)
      .padding(.bottom, MeetPRSpacing.space6)
      .frame(maxWidth: 520, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.MeetPR.bgBase)
    .hideNavigationBar()
  }
}

/// A large selectable role card (radio dot + title + mono tag + subtitle),
/// reproducing the design's `AuthFlow` role step.
@available(iOS 17.0, macOS 14.0, *)
private struct RoleCard: View {
  let role: UserRole
  @Binding var selectedRole: UserRole?

  private var active: Bool { selectedRole == role }

  var body: some View {
    Button {
      selectedRole = role
    } label: {
      HStack(spacing: MeetPRSpacing.point14) {
        Circle()
          .stroke(
            active ? Color.MeetPR.gold500 : Color.MeetPR.textTertiary,
            lineWidth: active ? 7 : 2
          )
          .frame(width: 26, height: 26)
        VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
          HStack(spacing: MeetPRSpacing.space2) {
            Text(role.authTitle)
              .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text(role.authTag)
              .font(.MeetPR.system(size: MeetPRFontMetrics.size10, design: .monospaced))
              .tracking(0.6)
              .foregroundStyle(Color.MeetPR.gold500)
              .padding(.horizontal, MeetPRSpacing.point7)
              .padding(.vertical, MeetPRSpacing.point2)
              .overlay {
                RoundedRectangle(cornerRadius: MeetPRRadius.point4).stroke(
                  Color.MeetPR.gold500.opacity(0.3), lineWidth: 1)
              }
          }
          Text(role.authSubtitle)
            .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
      }
      .padding(MeetPRSpacing.space5)
      .background(active ? Color.MeetPR.surfaceElevated : Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(active ? Color.MeetPR.gold500 : Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityIdentifier("signup.role.\(role.rawValue)")
  }
}

extension UserRole {
  fileprivate var authTitle: String {
    switch self {
    case .coach: "教练"
    case .coachedStudent: "学员 · 有教练"
    case .selfTrainStudent: "学员 · 自己练"
    }
  }

  fileprivate var authTag: String {
    switch self {
    case .coach: "COACH"
    case .coachedStudent: "COACHED"
    case .selfTrainStudent: "SELF_TRAIN"
    }
  }

  fileprivate var authSubtitle: String {
    switch self {
    case .coach: "编排周期 · 审阅学员 · 反馈视频"
    case .coachedStudent: "接收计划 · 记录训练 · 上传视频"
    case .selfTrainStudent: "选择训练模板 · 自主跟练"
    }
  }
}
