import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// 我的邀请码 (spec 031 §8): personal permanent card on top, single-use /
/// time-limited codes below, defunct codes sunk into their own section.
@available(iOS 17.0, macOS 14.0, *)
struct InviteCodesView: View {
  @State private var viewModel: InviteCodesViewModel
  @State private var createSheet: CreateCodeSheetKind?
  @State private var confirmRegenerate = false
  @State private var revokeTarget: InviteCode?

  init(repository: any InviteCodeRepository) {
    self._viewModel = State(initialValue: InviteCodesViewModel(repository: repository))
  }

  var body: some View {
    List {
      personalSection
      secondarySection
      if !viewModel.defunctSecondaryCodes.isEmpty {
        defunctSection
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .navigationTitle("我的邀请码")
    .task {
      await viewModel.loadIfNeeded()
    }
    .refreshable {
      await viewModel.reload()
    }
    .sheet(item: $createSheet) { kind in
      createSheetContent(kind)
    }
    .confirmationDialog(
      "重新生成永久码?",
      isPresented: $confirmRegenerate,
      titleVisibility: .visible
    ) {
      Button("重新生成", role: .destructive) {
        Task { await viewModel.generatePersonalCode() }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("重新生成后旧码立即失效,已分发的旧码将无法使用。")
    }
    .confirmationDialog(
      "撤销这个邀请码?",
      isPresented: Binding(
        get: { revokeTarget != nil },
        set: { if !$0 { revokeTarget = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("撤销", role: .destructive) {
        if let target = revokeTarget {
          Task { await viewModel.revoke(id: target.id) }
        }
        revokeTarget = nil
      }
      Button("取消", role: .cancel) { revokeTarget = nil }
    } message: {
      Text("撤销后该码立即失效。")
    }
  }

  @ViewBuilder
  private func createSheetContent(_ kind: CreateCodeSheetKind) -> some View {
    #if os(iOS)
      CreateCodeSheet(kind: kind, viewModel: viewModel)
        .presentationDetents([.medium])
    #else
      CreateCodeSheet(kind: kind, viewModel: viewModel)
    #endif
  }

  // MARK: - Personal permanent card

  private var personalSection: some View {
    Section("Personal 永久码") {
      if let code = viewModel.activePersonalCode {
        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text(InviteCodeFormat.grouped(code.code))
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("已使用 \(code.usedCount) 次")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          HStack(spacing: MeetPRSpacing.md) {
            SecondaryButton(viewModel.copiedCodeID == code.id ? "已复制" : "复制") {
              copy(code)
            }
            SecondaryButton("重新生成") {
              confirmRegenerate = true
            }
          }
        }
        .padding(.vertical, MeetPRSpacing.sm)
      } else {
        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text("还没有永久码 — 生成一张,随时分发给新学员。")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          // Explicit button, never auto-generated on load (spec 031 D6).
          PrimaryButton("生成我的永久码", isLoading: viewModel.isMutating) {
            Task { await viewModel.generatePersonalCode() }
          }
        }
        .padding(.vertical, MeetPRSpacing.sm)
      }
      if let actionError = viewModel.actionError {
        Text(actionError)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.brandRed)
      }
    }
    .listRowBackground(Color.MeetPR.surface1)
  }

  // MARK: - Single-use / time-limited

  private var secondarySection: some View {
    Section("一次性码 / 限时码") {
      HStack(spacing: MeetPRSpacing.md) {
        SecondaryButton("+ 一次性码") {
          createSheet = .singleUse
        }
        SecondaryButton("+ 限时码") {
          createSheet = .timeLimited
        }
      }
      .padding(.vertical, MeetPRSpacing.xs)

      ForEach(viewModel.liveSecondaryCodes) { code in
        codeRow(code)
          .swipeActions(edge: .trailing) {
            Button("撤销", role: .destructive) {
              revokeTarget = code
            }
          }
      }
    }
    .listRowBackground(Color.MeetPR.surface1)
  }

  private var defunctSection: some View {
    Section("已失效") {
      ForEach(viewModel.defunctSecondaryCodes) { code in
        codeRow(code)
          .opacity(0.5)
      }
    }
    .listRowBackground(Color.MeetPR.surface1)
  }

  private func codeRow(_ code: InviteCode) -> some View {
    let status = viewModel.status(of: code)
    return Button {
      guard !status.isDefunct else { return }
      copy(code)
    } label: {
      HStack(spacing: MeetPRSpacing.md) {
        VStack(alignment: .leading, spacing: 2) {
          Text(InviteCodeFormat.grouped(code.code))
            .font(Font.MeetPR.monoLabel)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          HStack(spacing: MeetPRSpacing.xs) {
            Text(code.type == .singleUse ? "一次性" : "限时")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.fgTertiary)
            if let label = code.label {
              Text("· \(label)")
                .font(Font.MeetPR.caption)
                .foregroundStyle(Color.MeetPR.fgSecondary)
            }
          }
        }
        Spacer()
        if viewModel.copiedCodeID == code.id {
          Text("已复制")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.brandRed)
        } else {
          Text(status.label)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
    .buttonStyle(.plain)
  }

  /// Clipboard always gets the raw ungrouped 10 chars (spec 031 D11).
  private func copy(_ code: InviteCode) {
    #if os(iOS)
      UIPasteboard.general.string = code.code
    #elseif os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(code.code, forType: .string)
    #endif
    viewModel.markCopied(code)
    Task {
      try? await Task.sleep(for: .seconds(2))
      viewModel.clearCopied()
    }
  }
}

// MARK: - Create sheet

enum CreateCodeSheetKind: String, Identifiable {
  case singleUse
  case timeLimited

  var id: String { rawValue }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CreateCodeSheet: View {
  let kind: CreateCodeSheetKind
  let viewModel: InviteCodesViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var label = ""
  @State private var expiryChoice: ExpiryChoice = .week
  @State private var customDays = 14

  private enum ExpiryChoice: Hashable {
    case week, month, custom
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      Text(kind == .singleUse ? "生成一次性码" : "生成限时码")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)

      MeetPRTextField("备注(选填,如学员姓名)", text: $label, placeholder: "给小明")

      if kind == .timeLimited {
        expiryPicker
      }

      PrimaryButton("生成", isFullWidth: true) {
        Task {
          await create()
          dismiss()
        }
      }
      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bg)
  }

  private var expiryPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text("有效期")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Picker("有效期", selection: $expiryChoice) {
        Text("7 天").tag(ExpiryChoice.week)
        Text("30 天").tag(ExpiryChoice.month)
        Text("自定义").tag(ExpiryChoice.custom)
      }
      .pickerStyle(.segmented)
      if expiryChoice == .custom {
        Stepper(value: $customDays, in: 1...365) {
          Text("\(customDays) 天")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }
      }
    }
  }

  private func create() async {
    switch kind {
    case .singleUse:
      await viewModel.createSingleUseCode(label: label)
    case .timeLimited:
      await viewModel.createTimeLimitedCode(label: label, expiresInDays: expiresInDays)
    }
  }

  private var expiresInDays: Int {
    switch expiryChoice {
    case .week: 7
    case .month: 30
    case .custom: customDays
    }
  }
}
