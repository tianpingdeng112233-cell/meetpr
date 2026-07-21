import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachChangePasswordSheet: View {
  @Bindable var viewModel: CoachChangePasswordViewModel
  let onSaved: () -> Void

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
            Text(message)
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.brandRed)
          } else {
            Text("新密码至少 8 位")
              .font(Font.MeetPR.footnote)
          }
        }

        if case .failed(let message) = viewModel.state {
          Label(message, systemImage: "exclamationmark.triangle")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.brandRed)
        }

        Button {
          Task {
            await viewModel.submit()
            if viewModel.state == .saved {
              onSaved()
            }
          }
        } label: {
          Text(viewModel.state == .submitting ? "提交中…" : "确认修改")
            .frame(maxWidth: .infinity)
            .font(Font.MeetPR.bodyEmphasis)
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
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
            .disabled(viewModel.state == .submitting)
        }
      }
    }
  }
}
