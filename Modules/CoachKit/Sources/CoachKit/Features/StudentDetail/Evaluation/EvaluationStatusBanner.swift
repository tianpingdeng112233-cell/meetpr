import DesignSystem
import SwiftUI

/// The evaluation-period strip atop StudentDetailView (spec 033 §6):
/// countdown / overdue line, progress bar, and the three actions. Rendered
/// only while the evaluation is live; refreshes per minute via TimelineView
/// (no resident Timer).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct EvaluationStatusBanner: View {
  let viewModel: EvaluationBannerViewModel
  /// True once the student already has a published plan — during a live
  /// evaluation that can only be the adaptation week (publish真 gate blocks
  /// regular plans), so the button flips to "查看适应周".
  let hasPublishedPlan: Bool
  let onSendAdaptationWeek: () -> Void
  let onViewAdaptationWeek: () -> Void
  let onOpenSummary: () -> Void

  @State private var showCompleteDialog = false

  var body: some View {
    TimelineView(.everyMinute) { context in
      Card(accessibilityLabel: "评估期") {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text(viewModel.statusText(now: context.date))
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(
              viewModel.isOverdue(now: context.date)
                ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary
            )

          ProgressView(value: viewModel.progress(now: context.date))
            .tint(
              viewModel.isOverdue(now: context.date)
                ? Color.MeetPR.gold500 : Color.MeetPR.success)

          if let error = viewModel.completeError {
            Text(error)
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.gold500)
          }

          actionRow
        }
      }
    }
    .confirmationDialog(
      "完成后即可发布正式 4 周计划。还没写评估总结的话,建议先写总结再完成。",
      isPresented: $showCompleteDialog,
      titleVisibility: .visible
    ) {
      Button("仍然完成") {
        Task { _ = await viewModel.complete() }
      }
      Button("先写总结") {
        onOpenSummary()
      }
      Button("取消", role: .cancel) {}
    }
  }

  private var actionRow: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      if hasPublishedPlan {
        SecondaryButton("查看适应周") {
          onViewAdaptationWeek()
        }
      } else {
        SecondaryButton("发适应周") {
          onSendAdaptationWeek()
        }
      }
      SecondaryButton("评估总结") {
        onOpenSummary()
      }
      Spacer()
      PrimaryButton("完成评估") {
        showCompleteDialog = true
      }
    }
  }
}
