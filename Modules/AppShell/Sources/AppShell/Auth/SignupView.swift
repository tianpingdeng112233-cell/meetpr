import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct SignupView: View {
  /// 内测注册开放的角色。solo(自练)线 2026-07-10 拍板暂不进 TestFlight 内测包:
  /// 注册入口隐藏、代码休眠(defer≠delete,先例 spec 033 评估期停用)。
  /// 恢复 solo 注册 = 改回 `UserRole.allCases`。
  static let offeredRoles: [UserRole] = UserRole.allCases.filter { $0 != .selfTrainStudent }

  @Environment(Session.self) private var session
  @State private var viewModel = AuthFormViewModel(mode: .signup)

  public init() {}

  public var body: some View {
    @Bindable var viewModel = viewModel

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // ── Brand hero ───────────────────────────────────────────────
        MeetPRMark(size: 56)
          .padding(.bottom, MeetPRSpacing.lg)

        Eyebrow("注册 · 角色")
        Text("选择你的角色")
          .font(.system(size: 40, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .padding(.top, 8)
        (Text("注册后角色将锁定。").foregroundStyle(Color.MeetPR.fgSecondary)
          + Text("多角色支持在 V1.5 评估。").foregroundStyle(Color.MeetPR.fgTertiary))
          .font(.system(size: 14))
          .padding(.top, 12)

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
        VStack(spacing: 12) {
          ForEach(Self.offeredRoles, id: \.self) { role in
            RoleCard(role: role, selectedRole: $viewModel.selectedRole)
          }
        }
        .accessibilityIdentifier("signup.role")
        .padding(.top, 26)

        if let toastMessage = viewModel.toastMessage {
          Text(toastMessage)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.brandRed)
            .accessibilityIdentifier("signup.toast")
            .padding(.top, MeetPRSpacing.md)
        }

        // ── Submit ───────────────────────────────────────────────────
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
        .padding(.top, 26)
      }
      .padding(.horizontal, 24)
      .padding(.top, 32)
      .padding(.bottom, 24)
      .frame(maxWidth: 520, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.MeetPR.bg)
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
      HStack(spacing: 14) {
        Circle()
          .stroke(
            active ? Color.MeetPR.fgPrimary : Color.MeetPR.fgTertiary,
            lineWidth: active ? 7 : 2
          )
          .frame(width: 26, height: 26)
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 8) {
            Text(role.authTitle)
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(role.authTag)
              .font(.system(size: 10, design: .monospaced))
              .tracking(0.6)
              .foregroundStyle(Color.MeetPR.brandRed)
              .padding(.horizontal, 7)
              .padding(.vertical, 2)
              .overlay {
                RoundedRectangle(cornerRadius: 4).stroke(
                  Color.MeetPR.brandRed.opacity(0.3), lineWidth: 1)
              }
          }
          Text(role.authSubtitle)
            .font(.system(size: 14))
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
      }
      .padding(20)
      .background(active ? Color.MeetPR.surface2 : Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(active ? Color.MeetPR.fgPrimary : Color.MeetPR.border, lineWidth: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
    case .selfTrainStudent: "随手记训练 · 看见成长"
    }
  }
}
