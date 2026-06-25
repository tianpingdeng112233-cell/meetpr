import DesignSystem
import SwiftUI

/// The accept two-choice modal (spec 033 §5, wiki §3.3): defaults to skipping
/// the evaluation period for a known student (beta onboards only known
/// students), or opt into a 7-day evaluation. The optional skip reason
/// (≤500 chars) only sends on the skip branch.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct AcceptBindRequestSheet: View {
  let studentName: String
  /// Returns true on success → the sheet dismisses itself.
  let onConfirm: (_ skipEvaluation: Bool, _ skipReason: String?) async -> Bool

  // Beta onboards only known students with no evaluation period, so default to
  // skipping it; the coach can still opt into the 7-day evaluation.
  @State private var skipEvaluation = true
  @State private var skipReason = ""
  @State private var isSubmitting = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
          Text("接收 \(studentName) 进入:")
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          choiceCard(
            title: "进入 7 天评估期",
            subtitle: "推荐:陌生 / 不熟悉的学员",
            isSelected: !skipEvaluation
          ) {
            skipEvaluation = false
          }

          choiceCard(
            title: "跳过评估期(熟人)",
            subtitle: "适合:已带过的 / 朋友介绍",
            isSelected: skipEvaluation
          ) {
            skipEvaluation = true
          }

          if skipEvaluation {
            TextField("原因(选填)", text: $skipReason, axis: .vertical)
              .lineLimit(2...4)
              .textFieldStyle(.roundedBorder)
              .onChange(of: skipReason) { _, newValue in
                if newValue.count > 500 {
                  skipReason = String(newValue.prefix(500))
                }
              }
          }

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
    let skip = skipEvaluation
    // The reason only travels on the skip branch (zod superRefine真 gate兜底).
    let reason = skip ? skipReason : nil
    Task {
      let succeeded = await onConfirm(skip, reason)
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

  private func choiceCard(
    title: String,
    subtitle: String,
    isSelected: Bool,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      Card(accessibilityLabel: title) {
        HStack(spacing: MeetPRSpacing.md) {
          Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
            .foregroundStyle(isSelected ? Color.MeetPR.brandRed : Color.MeetPR.fgTertiary)
          VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
            Text(title)
              .font(Font.MeetPR.bodyEmphasis)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(subtitle)
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }
          Spacer()
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(isSelected ? Color.MeetPR.brandRed : .clear, lineWidth: 2)
      }
    }
    .buttonStyle(.plain)
  }
}
