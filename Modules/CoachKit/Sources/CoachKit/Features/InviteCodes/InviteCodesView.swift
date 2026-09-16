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
    .background(Color.MeetPR.bgBase)
    .tint(Color.MeetPR.gold500)
    .navigationTitle(InviteCodeStrings.navigationTitle)
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
      InviteCodeStrings.regenerateTitle,
      isPresented: $confirmRegenerate,
      titleVisibility: .visible
    ) {
      Button(InviteCodeStrings.regenerate, role: .destructive) {
        Task { await viewModel.generatePersonalCode() }
      }
      Button(InviteCodeStrings.cancel, role: .cancel) {}
    } message: {
      Text(InviteCodeStrings.regenerateMessage)
    }
    .confirmationDialog(
      InviteCodeStrings.revokeTitle,
      isPresented: Binding(
        get: { revokeTarget != nil },
        set: { if !$0 { revokeTarget = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(InviteCodeStrings.revoke, role: .destructive) {
        if let target = revokeTarget {
          Task { await viewModel.revoke(id: target.id) }
        }
        revokeTarget = nil
      }
      Button(InviteCodeStrings.cancel, role: .cancel) { revokeTarget = nil }
    } message: {
      Text(InviteCodeStrings.revokeMessage)
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
    Section(InviteCodeStrings.personalSection) {
      if let code = viewModel.activePersonalCode {
        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text(InviteCodeFormat.grouped(code.code))
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(InviteCodeStrings.usedCount(code.usedCount))
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
          HStack(spacing: MeetPRSpacing.md) {
            SecondaryButton(
              viewModel.copiedCodeID == code.id
                ? InviteCodeStrings.copied
                : InviteCodeStrings.copy
            ) {
              copy(code)
            }
            SecondaryButton(InviteCodeStrings.regenerate) {
              confirmRegenerate = true
            }
          }
        }
        .padding(.vertical, MeetPRSpacing.sm)
      } else {
        VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
          Text(InviteCodeStrings.noPermanentCode)
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textSecondary)
          // Explicit button, never auto-generated on load (spec 031 D6).
          PrimaryButton(
            InviteCodeStrings.generatePermanentCode,
            isLoading: viewModel.isMutating
          ) {
            Task { await viewModel.generatePersonalCode() }
          }
        }
        .padding(.vertical, MeetPRSpacing.sm)
      }
      if let actionError = viewModel.actionError {
        Text(actionError)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.danger)
      }
    }
    .listRowBackground(Color.MeetPR.surfaceCard)
  }

  // MARK: - Single-use / time-limited

  private var secondarySection: some View {
    Section(InviteCodeStrings.secondarySection) {
      HStack(spacing: MeetPRSpacing.md) {
        SecondaryButton(InviteCodeStrings.singleUseCode) {
          createSheet = .singleUse
        }
        SecondaryButton(InviteCodeStrings.timeLimitedCode) {
          createSheet = .timeLimited
        }
      }
      .padding(.vertical, MeetPRSpacing.xs)

      ForEach(viewModel.liveSecondaryCodes) { code in
        codeRow(code)
          .swipeActions(edge: .trailing) {
            Button(InviteCodeStrings.revoke, role: .destructive) {
              revokeTarget = code
            }
          }
      }
    }
    .listRowBackground(Color.MeetPR.surfaceCard)
  }

  private var defunctSection: some View {
    Section(InviteCodeStrings.defunctSection) {
      ForEach(viewModel.defunctSecondaryCodes) { code in
        codeRow(code)
          .opacity(0.5)
      }
    }
    .listRowBackground(Color.MeetPR.surfaceCard)
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
            .foregroundStyle(Color.MeetPR.textPrimary)
          HStack(spacing: MeetPRSpacing.xs) {
            Text(
              code.type == .singleUse
                ? InviteCodeStrings.singleUse
                : InviteCodeStrings.timeLimited
            )
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.textTertiary)
            if let label = code.label {
              Text("· \(label)")
                .font(Font.MeetPR.caption)
                .foregroundStyle(Color.MeetPR.textSecondary)
            }
          }
        }
        Spacer()
        if viewModel.copiedCodeID == code.id {
          Text(InviteCodeStrings.copied)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.gold500)
        } else {
          Text(status.label)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
      }
    }
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
      Text(
        kind == .singleUse
          ? InviteCodeStrings.createSingleUse
          : InviteCodeStrings.createTimeLimited
      )
      .font(Font.MeetPR.title2)
      .foregroundStyle(Color.MeetPR.textPrimary)

      MeetPRTextField(
        InviteCodeStrings.optionalLabel,
        text: $label,
        placeholder: InviteCodeStrings.labelPlaceholder
      )

      if kind == .timeLimited {
        expiryPicker
      }

      PrimaryButton(InviteCodeStrings.generate, isFullWidth: true) {
        Task {
          await create()
          dismiss()
        }
      }
      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .background(Color.MeetPR.bgBase)
  }

  private var expiryPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(InviteCodeStrings.validity)
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.textPrimary)
      Picker(InviteCodeStrings.validity, selection: $expiryChoice) {
        Text(InviteCodeStrings.sevenDays).tag(ExpiryChoice.week)
        Text(InviteCodeStrings.thirtyDays).tag(ExpiryChoice.month)
        Text(InviteCodeStrings.custom).tag(ExpiryChoice.custom)
      }
      .pickerStyle(.segmented)
      if expiryChoice == .custom {
        Stepper(value: $customDays, in: 1...365) {
          Text(InviteCodeStrings.days(customDays))
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textPrimary)
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
