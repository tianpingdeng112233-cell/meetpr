import CoreModels
import DesignSystem
import Observation
import RepositoryContracts
import SwiftUI

/// 我的页「账号与安全」区 (spec 048 §1): self-contained — owns its sheet
/// view models (@State: per-body-eval rebuilds would drop typing state,
/// spec 051 lesson) and the three presentations.
@available(iOS 17.0, macOS 14.0, *)
struct AccountSecuritySection: View {
  let studentID: UUID
  let account: any AccountRepository
  let logs: (any StudentTrainingLogRepository)?
  let catalog: [Exercise]
  let onLogout: (@MainActor () async -> Void)?

  @State private var changePasswordViewModel: ChangePasswordViewModel?
  @State private var deleteAccountViewModel: DeleteAccountViewModel?
  @State private var exportViewModel: ExportDataViewModel?
  @State private var showsChangePassword = false
  @State private var showsDeleteAccount = false
  @State private var showsExport = false

  var body: some View {
    VStack(spacing: 0) {
      row(icon: "key", title: "改密码", tint: Color.MeetPR.fgPrimary) {
        changePasswordViewModel = ChangePasswordViewModel(account: account)
        showsChangePassword = true
      }
      .accessibilityIdentifier("account.changePassword")

      if let logs {
        separator
        row(icon: "square.and.arrow.up", title: "导出训练数据", tint: Color.MeetPR.fgPrimary) {
          exportViewModel = ExportDataViewModel(logs: logs, catalog: catalog)
          showsExport = true
        }
        .accessibilityIdentifier("account.export")
      }

      separator
      row(icon: "trash", title: "注销账号", tint: Color.MeetPR.brandRed) {
        deleteAccountViewModel = DeleteAccountViewModel(account: account) {
          await onLogout?()
        }
        showsDeleteAccount = true
      }
      .accessibilityIdentifier("account.delete")
    }
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
    .sheet(
      isPresented: $showsChangePassword,
      onDismiss: { changePasswordViewModel = nil },
      content: {
        if let changePasswordViewModel {
          ChangePasswordSheet(viewModel: changePasswordViewModel)
            .presentationDetents([.medium, .large])
        }
      }
    )
    .sheet(
      isPresented: $showsDeleteAccount,
      onDismiss: { deleteAccountViewModel = nil },
      content: {
        if let deleteAccountViewModel {
          DeleteAccountSheet(viewModel: deleteAccountViewModel)
            .presentationDetents([.large])
        }
      }
    )
    .sheet(
      isPresented: $showsExport,
      onDismiss: { exportViewModel = nil },
      content: {
        if let exportViewModel {
          ExportDataSheet(viewModel: exportViewModel, studentID: studentID)
            .presentationDetents([.medium])
        }
      }
    )
  }

  private var separator: some View {
    Rectangle().fill(Color.MeetPR.border).frame(height: 1)
  }

  private func row(
    icon: String, title: String, tint: Color, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 16)).frame(width: 24)
        Text(title).font(.system(size: 15))
        Spacer()
        Image(systemName: "chevron.right").font(.system(size: 13))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .foregroundStyle(tint)
      .padding(14)
    }
    .buttonStyle(.plain)
  }
}

/// 注销账号 (spec 048 §2): explain, demand the confirmation word, delete.
@available(iOS 17.0, macOS 14.0, *)
struct DeleteAccountSheet: View {
  @Bindable var viewModel: DeleteAccountViewModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          Text("账号与全部训练数据将永久删除,无法恢复。")
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          VStack(alignment: .leading, spacing: 6) {
            bullet("全部训练记录与组数据")
            bullet("e1RM 历史与 PR")
            bullet("训练回顾与状态问卷")
            bullet("个人资料与入门基线")
          }

          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Text("输入「\(DeleteAccountViewModel.requiredWord)」以确认")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
            TextField(DeleteAccountViewModel.requiredWord, text: $viewModel.confirmationText)
              .textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("account.delete.confirmField")
          }

          if case .failed(let message) = viewModel.state {
            Label(message, systemImage: "exclamationmark.triangle")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.brandRed)
          }

          Button {
            Task { await viewModel.submit() }
          } label: {
            Text(viewModel.state == .deleting ? "删除中…" : "永久删除我的账号")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .disabled(!viewModel.canSubmit)
          .accessibilityIdentifier("account.delete.submit")
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle("注销账号")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }

  private func bullet(_ text: String) -> some View {
    HStack(spacing: 6) {
      Circle().fill(Color.MeetPR.fgTertiary).frame(width: 4, height: 4)
      Text(text).font(Font.MeetPR.caption).foregroundStyle(Color.MeetPR.fgSecondary)
    }
  }
}

/// 改密码 (spec 048 §3).
@available(iOS 17.0, macOS 14.0, *)
struct ChangePasswordSheet: View {
  @Bindable var viewModel: ChangePasswordViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("旧密码", text: $viewModel.oldPassword)
            .accessibilityIdentifier("account.password.old")
          SecureField("新密码(至少 8 位)", text: $viewModel.newPassword)
            .accessibilityIdentifier("account.password.new")
          SecureField("再输一次新密码", text: $viewModel.confirmPassword)
            .accessibilityIdentifier("account.password.confirm")
        } footer: {
          if let message = viewModel.localValidationMessage {
            Text(message).foregroundStyle(Color.MeetPR.brandRed)
          } else {
            Text("修改后其他设备将退出登录")
          }
        }

        switch viewModel.state {
        case .saved:
          Label("密码已更新", systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.green)
        case .failed(let message):
          Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.MeetPR.brandRed)
        case .idle, .submitting:
          EmptyView()
        }

        Button {
          Task {
            await viewModel.submit()
            if viewModel.state == .saved {
              try? await Task.sleep(for: .seconds(1))
              dismiss()
            }
          }
        } label: {
          Text(viewModel.state == .submitting ? "提交中…" : "确认修改")
            .frame(maxWidth: .infinity)
            .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.MeetPR.brandRed)
        .disabled(!viewModel.canSubmit)
        .accessibilityIdentifier("account.password.submit")
      }
      .navigationTitle("改密码")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }
}

/// 导出训练数据 (spec 048 §4): fetch everything, write a temp CSV, share.
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class ExportDataViewModel {
  public enum State: Equatable {
    case idle
    case generating
    case ready(URL)
    case failed(String)
  }

  public private(set) var state: State = .idle

  private let logs: any StudentTrainingLogRepository
  private let names: [UUID: (name: String, nameEn: String?)]
  private let now: @Sendable () -> Date

  public init(
    logs: any StudentTrainingLogRepository,
    catalog: [Exercise],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.logs = logs
    self.names = Dictionary(
      catalog.map { ($0.id, (name: $0.name, nameEn: $0.nameEn)) },
      uniquingKeysWith: { first, _ in first })
    self.now = now
  }

  public func export(studentID: UUID) async {
    guard state != .generating else { return }
    state = .generating
    do {
      // 全量导出绕开 180 天产品窗 (spec 048 §4): a fixed wide window.
      let start = Date(timeIntervalSince1970: 946_684_800)  // 2000-01-01
      let fetched = try await logs.fetchLogs(
        studentID: studentID, in: start...now(), scope: .all)
      let csv = TrainingLogCSVExporter.csv(logs: fetched, names: names)
      let stamp = SoloSessionViewModel.dayString(now(), calendar: .current)
        .replacingOccurrences(of: "-", with: "")
      let url = FileManager.default.temporaryDirectory
        .appending(path: "meetpr-training-log-\(stamp).csv")
      try Data(csv.utf8).write(to: url, options: .atomic)
      state = .ready(url)
    } catch {
      state = .failed("导出失败,请检查网络后重试")
    }
  }
}

/// Small share surface: generation state + ShareLink once the file exists.
@available(iOS 17.0, macOS 14.0, *)
struct ExportDataSheet: View {
  @Bindable var viewModel: ExportDataViewModel
  let studentID: UUID

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.lg) {
        switch viewModel.state {
        case .idle, .generating:
          ProgressView("正在整理你的全部训练数据…")
        case .failed(let message):
          Label(message, systemImage: "exclamationmark.triangle")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.brandRed)
          Button("重试") {
            Task { await viewModel.export(studentID: studentID) }
          }
        case .ready(let url):
          Label("CSV 已生成", systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.green)
          Text("包含全部训练组:日期/动作/重量/次数/RPE。")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          ShareLink(item: url) {
            Label("分享 / 存储", systemImage: "square.and.arrow.up")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .accessibilityIdentifier("account.export.share")
        }
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .navigationTitle("导出训练数据")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .task { await viewModel.export(studentID: studentID) }
    }
  }
}
