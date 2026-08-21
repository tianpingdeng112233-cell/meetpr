import DesignSystem
import Observation
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct AccountSecuritySection: View {
  let studentID: UUID
  let account: any AccountRepository
  let logs: any StudentTrainingLogRepository
  let plans: any StudentPlanRepository
  let onLogout: (@MainActor () async -> Void)?
  var showsDeleteAccount = true

  @State private var changePasswordPresentation: ChangePasswordPresentation?
  @State private var deleteAccountPresentation: DeleteAccountPresentation?
  @State private var exportPresentation: ExportPresentation?
  @State private var exportCleanupViewModel: ExportDataViewModel?
  @State private var showsPasswordUpdated = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    accountRows
      .sheet(
        item: $changePasswordPresentation,
        content: changePasswordSheet
      )
      .sheet(
        item: $exportPresentation,
        onDismiss: discardExport,
        content: exportSheet
      )
      .deleteAccountPresentation(
        item: $deleteAccountPresentation,
        content: deleteAccountSheet
      )
      .overlay(alignment: .bottom) {
        if showsPasswordUpdated {
          passwordUpdatedToast
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
  }

  private var accountRows: some View {
    VStack(spacing: 0) {
      row(
        icon: "key", title: StudentStrings.localized(.accountSecuritySheets001),
        tint: Color.MeetPR.textSecondary
      ) {
        changePasswordPresentation = ChangePasswordPresentation(
          viewModel: ChangePasswordViewModel(account: account)
        )
      }
      .accessibilityIdentifier("account.changePassword")

      separator
      row(
        icon: "square.and.arrow.up", title: StudentStrings.localized(.accountSecuritySheets002),
        tint: Color.MeetPR.textSecondary
      ) {
        let viewModel = ExportDataViewModel(logs: logs, plans: plans)
        exportCleanupViewModel = viewModel
        exportPresentation = ExportPresentation(viewModel: viewModel)
      }
      .accessibilityIdentifier("account.export")

      if showsDeleteAccount {
        separator
        row(
          icon: "trash", title: StudentStrings.localized(.accountSecuritySheets003),
          tint: Color.MeetPR.dangerMuted
        ) {
          deleteAccountPresentation = DeleteAccountPresentation(
            viewModel: DeleteAccountViewModel(account: account) {
              await onLogout?()
            }
          )
        }
        .accessibilityIdentifier("account.delete")
      }
    }
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  @ViewBuilder
  private func changePasswordSheet(
    _ presentation: ChangePasswordPresentation
  ) -> some View {
    ChangePasswordSheet(viewModel: presentation.viewModel) {
      changePasswordPresentation = nil
      showPasswordUpdatedToast()
    }
    .presentationDetents([.medium, .large])
  }

  @ViewBuilder
  private func exportSheet(_ presentation: ExportPresentation) -> some View {
    ExportDataSheet(viewModel: presentation.viewModel, studentID: studentID)
      .presentationDetents([.medium])
  }

  @ViewBuilder
  private func deleteAccountSheet(
    _ presentation: DeleteAccountPresentation
  ) -> some View {
    DeleteAccountSheet(viewModel: presentation.viewModel)
  }

  private var passwordUpdatedToast: some View {
    Label(StudentStrings.localized(.accountSecuritySheets004), systemImage: "checkmark.circle.fill")
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(.horizontal, MeetPRSpacing.base)
      .padding(.vertical, MeetPRSpacing.sm)
      .background(Color.MeetPR.surfaceRaised)
      .clipShape(.capsule)
      .shadow(radius: 8)
      .accessibilityIdentifier("account.password.updated")
  }

  private var separator: some View {
    Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
  }

  private func row(
    icon: String,
    title: String,
    tint: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.point13) {
        Image(systemName: icon)
          .font(.system(size: MeetPRFontMetrics.size20))
          .frame(width: 20)
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDim)
      }
      .foregroundStyle(tint)
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.vertical, MeetPRSpacing.point15)
      .frame(minHeight: 52)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func showPasswordUpdatedToast() {
    setPasswordUpdated(true)
    Task {
      try? await Task.sleep(for: .seconds(2))
      setPasswordUpdated(false)
    }
  }

  private func setPasswordUpdated(_ isVisible: Bool) {
    if reduceMotion {
      showsPasswordUpdated = isVisible
    } else {
      withAnimation {
        showsPasswordUpdated = isVisible
      }
    }
  }

  private func discardExport() {
    exportCleanupViewModel?.discardExport()
    exportCleanupViewModel = nil
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ChangePasswordPresentation: Identifiable {
  let id = UUID()
  let viewModel: ChangePasswordViewModel
}

@available(iOS 17.0, macOS 14.0, *)
private struct DeleteAccountPresentation: Identifiable {
  let id = UUID()
  let viewModel: DeleteAccountViewModel
}

@available(iOS 17.0, macOS 14.0, *)
private struct ExportPresentation: Identifiable {
  let id = UUID()
  let viewModel: ExportDataViewModel
}

@available(iOS 17.0, macOS 14.0, *)
extension View {
  @ViewBuilder
  fileprivate func deleteAccountPresentation<Item: Identifiable, Content: View>(
    item: Binding<Item?>,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    #if os(iOS)
      fullScreenCover(item: item, content: content)
    #else
      sheet(item: item, content: content)
    #endif
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DeleteAccountSheet: View {
  @Bindable var viewModel: DeleteAccountViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          Text(StudentStrings.localized(.accountSecuritySheets005))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)

          VStack(alignment: .leading, spacing: 6) {
            bullet(StudentStrings.localized(.accountSecuritySheets006))
            bullet(StudentStrings.localized(.accountSecuritySheets007))
            bullet(StudentStrings.localized(.accountSecuritySheets008))
            bullet(StudentStrings.localized(.accountSecuritySheets009))
          }

          VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
            Text(
              StudentStrings.replacing(
                .accountSecuritySheets010, values: ["\(DeleteAccountViewModel.requiredWord)"])
            )
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.textSecondary)
            TextField(DeleteAccountViewModel.requiredWord, text: $viewModel.confirmationText)
              .textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("account.delete.confirmField")
          }

          if case .failed(let message) = viewModel.state {
            Label(message, systemImage: "exclamationmark.triangle")
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
              .foregroundStyle(Color.MeetPR.dangerMuted)
          }

          GoldCTA(
            viewModel.state == .deleting
              ? StudentStrings.localized(.accountSecuritySheets011)
              : StudentStrings.localized(.accountSecuritySheets012),
            sub: nil,
            variant: .danger,
            icon: .none,
            isDisabled: !viewModel.canSubmit,
            isLoading: viewModel.state == .deleting
          ) {
            Task { await viewModel.submit() }
          }
          .accessibilityIdentifier("account.delete.submit")
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bgBase)
      .navigationTitle(StudentStrings.localized(.accountSecuritySheets003))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(StudentStrings.localized(.accountSecuritySheets013)) { dismiss() }
            .disabled(viewModel.state == .deleting)
        }
      }
    }
  }

  private func bullet(_ text: String) -> some View {
    HStack(spacing: 6) {
      Circle().fill(Color.MeetPR.textTertiary).frame(width: 4, height: 4)
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct ChangePasswordSheet: View {
  @Bindable var viewModel: ChangePasswordViewModel
  let onSaved: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField(
            StudentStrings.localized(.accountSecuritySheets014), text: $viewModel.oldPassword
          )
          .accessibilityIdentifier("account.password.old")
          SecureField(
            StudentStrings.localized(.accountSecuritySheets015), text: $viewModel.newPassword
          )
          .accessibilityIdentifier("account.password.new")
          SecureField(
            StudentStrings.localized(.accountSecuritySheets016), text: $viewModel.confirmPassword
          )
          .accessibilityIdentifier("account.password.confirm")
        } footer: {
          if let message = viewModel.localValidationMessage {
            Text(message).foregroundStyle(Color.MeetPR.dangerMuted)
          } else {
            Text(StudentStrings.localized(.accountSecuritySheets017))
          }
        }

        if case .failed(let message) = viewModel.state {
          Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(Color.MeetPR.dangerMuted)
        }

        GoldCTA(
          viewModel.state == .submitting
            ? StudentStrings.localized(.accountSecuritySheets018)
            : StudentStrings.localized(.accountSecuritySheets019),
          sub: nil,
          icon: .none,
          isDisabled: !viewModel.canSubmit,
          isLoading: viewModel.state == .submitting
        ) {
          Task {
            await viewModel.submit()
            if viewModel.state == .saved {
              onSaved()
            }
          }
        }
        .accessibilityIdentifier("account.password.submit")
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .navigationTitle(StudentStrings.localized(.accountSecuritySheets001))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(StudentStrings.localized(.accountSecuritySheets013)) { dismiss() }
            .disabled(viewModel.state == .submitting)
        }
      }
    }
  }
}
