import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Coach "我的" tab, reskinned 1:1 to the `DKCoachProfile` mock: an identity
/// card, the permanent invite-code card (with the live code + scan count
/// previewed inline), and a stacked rows card for the remaining entries.
///
/// All real behavior is preserved — the 我的邀请码 feature still pushes the full
/// `InviteCodesView` (generate / regenerate / single-use / revoke / copy live
/// there), the App 版本 row reads `viewModel.appVersion`, and 退出登录 calls
/// `viewModel.logout()`. The mock's avatar/name/student-count, QR glyph, "分享"
/// button, and 自定义动作库 / 订阅管理 / 设置 rows have no backing model and are
/// degraded honestly (see file-level notes / honestDegrades).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachMyProfileView: View {
  @Bindable private var viewModel: CoachMyProfileViewModel
  private let inviteCodes: any InviteCodeRepository
  private let chat: CoachChatContext?
  /// Local read-model so the permanent code + scan count can be previewed on
  /// this screen; the full mutate/list UI still lives in `InviteCodesView`.
  @State private var codesViewModel: InviteCodesViewModel
  @State private var isConversationListPresented = false

  init(
    viewModel: CoachMyProfileViewModel,
    inviteCodes: any InviteCodeRepository,
    chat: CoachChatContext? = nil
  ) {
    self.viewModel = viewModel
    self.inviteCodes = inviteCodes
    self.chat = chat
    self._codesViewModel = State(initialValue: InviteCodesViewModel(repository: inviteCodes))
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        HStack {
          Text("我的")
            .font(.MeetPR.display(size: 34, weight: .extraBold))
            .tracking(-0.7)
            .foregroundStyle(Color.MeetPR.textPrimary)
          Spacer()
          CoachChatHeaderButton(chat: chat) {
            isConversationListPresented = true
          }
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.space2)
        .meetPRRiseIn(index: 0)

        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
            identityCard
            inviteCard
            rowsCard
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
          .padding(.vertical, MeetPRSpacing.point14)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await codesViewModel.reload() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(isPresented: $isConversationListPresented) {
        if let chat {
          ConversationListView(chat: chat)
        }
      }
    }
    .task { await codesViewModel.loadIfNeeded() }
  }

  // MARK: - Identity

  // The mock shows an avatar initial, coach name, and "教练 · 14 名学员". None
  // of those are on `CoachMyProfileViewModel`, so we degrade to the role line
  // without a fabricated name/count, keeping the card's framing.
  private var identityCard: some View {
    card {
      HStack(spacing: MeetPRSpacing.point14) {
        Image(systemName: "person.fill")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .bold))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .frame(width: 52, height: 52)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(Circle())
          .overlay { Circle().stroke(Color.MeetPR.borderDefault, lineWidth: 1) }
        VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
          Text("教练")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("MeetPR · V0.1 内测")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.gold500)
        }
        Spacer()
      }
    }
  }

  // MARK: - Invite code

  // Reproduces the mock's permanent-code card: the live code in big mono, the
  // real scan/use count, and an action row. The mock's QR glyph + "分享" have no
  // backend (no QR payload, no share sheet wiring), so the card pushes the real
  // `InviteCodesView` where the code is generated / copied / managed.
  private var inviteCard: some View {
    NavigationLink {
      InviteCodesView(repository: inviteCodes)
    } label: {
      card {
        VStack(alignment: .leading, spacing: MeetPRSpacing.zero) {
          HStack {
            Text("永久邀请码")
              .font(Font.MeetPR.monoLabel)
              .tracking(Font.MeetPR.monoLabelTracking)
              .foregroundStyle(Color.MeetPR.gold500)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }

          if let code = codesViewModel.activePersonalCode {
            Text(InviteCodeFormat.grouped(code.code))
              .font(.MeetPR.mono(size: 26, weight: .bold))
              .tracking(1.5)
              .foregroundStyle(Color.MeetPR.textPrimary)
              .padding(.top, MeetPRSpacing.point10)
            Text("已使用 \(code.usedCount) 次")
              .font(
                .MeetPR.system(size: MeetPRFontMetrics.size11, weight: .medium, design: .monospaced)
              )
              .tracking(0.8)
              .foregroundStyle(Color.MeetPR.textTertiary)
              .padding(.top, MeetPRSpacing.space2)
          } else {
            Text(inviteSubtitle)
              .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
              .foregroundStyle(Color.MeetPR.textSecondary)
              .padding(.top, MeetPRSpacing.point10)
          }
        }
      }
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var inviteSubtitle: String {
    switch codesViewModel.state {
    case .idle, .loading: "加载中…"
    case .failed: "加载失败 · 点击重试"
    case .loaded: "还没有永久码 · 点击生成"
    }
  }

  // MARK: - Rows

  // The mock lists 自定义动作库 / 订阅管理 / 设置 (none exist yet) plus implicit
  // version + logout. We keep the real, wired rows: App 版本 (read-only value)
  // and 退出登录 (the destructive logout action). Unbuilt features are omitted
  // rather than shown as dead rows.
  private var rowsCard: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      versionRow
      divider
      logoutRow
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }

  private var versionRow: some View {
    HStack(spacing: MeetPRSpacing.point14) {
      Image(systemName: "info.circle")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(width: 22)
      Text("App 版本")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Spacer()
      Text(viewModel.appVersion)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .frame(minHeight: 56)
  }

  private var logoutRow: some View {
    Button {
      Task { @MainActor in
        await viewModel.logout()
      }
    } label: {
      HStack(spacing: MeetPRSpacing.point14) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20))
          .foregroundStyle(Color.MeetPR.gold500)
          .frame(width: 22)
        Text(viewModel.isLoggingOut ? "退出中" : "退出登录")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
        Spacer()
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.point14)
      .frame(minHeight: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(viewModel.isLoggingOut)
  }

  // MARK: - Building blocks

  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: MeetPRSpacing.zero) { content() }
      .padding(MeetPRSpacing.space4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control).stroke(
          Color.MeetPR.borderDefault, lineWidth: 1)
      }
  }

  private var divider: some View {
    Rectangle().fill(Color.MeetPR.borderDefault).frame(height: 1)
  }
}
