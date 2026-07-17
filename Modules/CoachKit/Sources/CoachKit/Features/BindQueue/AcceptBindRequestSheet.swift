import DesignSystem
import SwiftUI

/// The accept confirm modal.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct AcceptBindRequestSheet: View {
  let studentName: String
  /// Returns true on success → the sheet dismisses itself.
  let onConfirm: () async -> Bool

  @State private var isSubmitting = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
          Text("确认接收 \(studentName) 为学员?")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Text("接收后即可为其查看资料、编排训练计划。")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)

          PrimaryButton("确认接收", isDisabled: isSubmitting, isFullWidth: true) {
            submit()
          }
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle("接收新学员")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") {
            dismiss()
          }
          .disabled(isSubmitting)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func submit() {
    guard !isSubmitting else { return }
    isSubmitting = true
    Task {
      let succeeded = await onConfirm()
      isSubmitting = false
      if succeeded {
        dismiss()
      } else {
        // Failure surfaces on the queue banner (D12) — close so the
        // refreshed queue is visible.
        dismiss()
      }
    }
  }
}
