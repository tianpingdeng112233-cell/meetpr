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
      Card(accessibilityLabel: CoachStudentDetailStrings.text("coach.evaluation.title")) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text(viewModel.statusText(now: context.date))
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(
              viewModel.isOverdue(now: context.date)
                ? Color.MeetPR.brandRed : Color.MeetPR.fgPrimary
            )

          ProgressView(value: viewModel.progress(now: context.date))
            .tint(
              viewModel.isOverdue(now: context.date)
                ? Color.MeetPR.brandRed : Color.MeetPR.green)

          if let error = viewModel.completeError {
            Text(error)
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.amber)
          }

          actionRow
        }
      }
    }
    .confirmationDialog(
      CoachStudentDetailStrings.text("coach.evaluation.complete.confirmation"),
      isPresented: $showCompleteDialog,
      titleVisibility: .visible
    ) {
      Button(CoachStudentDetailStrings.text("coach.evaluation.complete.anyway")) {
        Task { _ = await viewModel.complete() }
      }
      Button(CoachStudentDetailStrings.text("coach.evaluation.complete.writeSummary")) {
        onOpenSummary()
      }
      Button(CoachStudentDetailStrings.text("coach.common.cancel"), role: .cancel) {}
    }
  }

  private var actionRow: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      if hasPublishedPlan {
        SecondaryButton(CoachStudentDetailStrings.text("coach.evaluation.viewAdaptation")) {
          onViewAdaptationWeek()
        }
      } else {
        SecondaryButton(CoachStudentDetailStrings.text("coach.evaluation.sendAdaptation")) {
          onSendAdaptationWeek()
        }
      }
      SecondaryButton(CoachStudentDetailStrings.text("coach.evaluation.summary")) {
        onOpenSummary()
      }
      Spacer()
      PrimaryButton(CoachStudentDetailStrings.text("coach.evaluation.complete")) {
        showCompleteDialog = true
      }
    }
  }
}
