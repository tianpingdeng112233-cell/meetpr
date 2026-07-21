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
      VStack(spacing: 0) {
        HStack {
          Text("我的")
            .font(.system(size: 36, weight: .heavy))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Spacer()
          CoachChatHeaderButton(chat: chat) {
            isConversationListPresented = true
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            identityCard
            inviteCard
            rowsCard
          }
          .padding(16)
        }
        .scrollContentBackground(.hidden)
        .refreshable { await codesViewModel.reload() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
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
      HStack(spacing: 14) {
        Image(systemName: "person.fill")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .frame(width: 52, height: 52)
          .background(Color.MeetPR.surface2)
          .clipShape(Circle())
          .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
        VStack(alignment: .leading, spacing: 2) {
          Text("教练")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("MeetPR · V0.1 内测")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.brandRed)
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
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            Text("永久邀请码")
              .font(Font.MeetPR.monoLabel)
              .tracking(Font.MeetPR.monoLabelTracking)
              .foregroundStyle(Color.MeetPR.brandRed)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13))
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }

          if let code = codesViewModel.activePersonalCode {
            Text(InviteCodeFormat.grouped(code.code))
              .font(.system(size: 24, weight: .bold, design: .monospaced))
              .tracking(1.5)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .padding(.top, 10)
            Text("已使用 \(code.usedCount) 次")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .tracking(0.8)
              .foregroundStyle(Color.MeetPR.fgTertiary)
              .padding(.top, 8)
          } else {
            Text(inviteSubtitle)
              .font(.system(size: 16))
              .foregroundStyle(Color.MeetPR.fgSecondary)
              .padding(.top, 10)
          }
        }
      }
    }
    .buttonStyle(.plain)
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
    VStack(spacing: 0) {
      versionRow
      divider
      logoutRow
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private var versionRow: some View {
    HStack(spacing: 14) {
      Image(systemName: "info.circle")
        .font(.system(size: 20))
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .frame(width: 22)
      Text("App 版本")
        .font(.system(size: 16))
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      Text(viewModel.appVersion)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(minHeight: 56)
  }

  private var logoutRow: some View {
    Button {
      Task { @MainActor in
        await viewModel.logout()
      }
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .font(.system(size: 20))
          .foregroundStyle(Color.MeetPR.brandRed)
          .frame(width: 22)
        Text(viewModel.isLoggingOut ? "退出中" : "退出登录")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.brandRed)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(minHeight: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(viewModel.isLoggingOut)
  }

  // MARK: - Building blocks

  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) { content() }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: 12))
      .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private var divider: some View {
    Rectangle().fill(Color.MeetPR.border).frame(height: 1)
  }
}
