import DesignSystem
import SwiftUI

struct VideoCompletionControl: View {
  var presentation: VideoCompletionPresentation?
  var coordinator: SetSyncCompletionCoordinator?
  let onComplete: () -> Void
  var onRetry: () -> Void = {}

  var body: some View {
    if let presentation, presentation.waiting {
      waitingCard(presentation)
    } else {
      VStack(spacing: MeetPRSpacing.space2) {
        if let presentation, presentation.showsSummary, coordinator?.phase ?? .idle == .idle {
          summary(presentation)
        }
        SetSyncCompletionControl(coordinator: coordinator, onComplete: onComplete)
        if presentation?.showsSummary == true, coordinator?.phase ?? .idle == .idle {
          Text(StudentStrings.localized(.videoCompletionHint))
            .font(.caption)
            .foregroundStyle(Color.MeetPR.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func summary(_ presentation: VideoCompletionPresentation) -> some View {
    HStack(spacing: MeetPRSpacing.space2) {
      if presentation.failed > 0 { Image(systemName: "exclamationmark.triangle.fill") }
      Text(
        StudentStrings.replacing(
          presentation.failed > 0 ? .videoCompletionSummary : .videoCompletionUploading,
          values: presentation.failed > 0
            ? [String(presentation.failed), String(presentation.uploading)]
            : [String(presentation.uploading)])
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      if presentation.failed > 0 {
        Button(StudentStrings.localized(.videoRetryNow), action: onRetry)
          .font(.callout.bold())
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
    }
    .font(.footnote)
    .foregroundStyle(presentation.failed > 0 ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
    .accessibilityIdentifier("videoCompletion.summary")
  }

  private func waitingCard(_ presentation: VideoCompletionPresentation) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Label(
        StudentStrings.replacing(
          .videoCompletionProgress,
          values: [String(presentation.done), String(presentation.total)]),
        systemImage: "arrow.up.circle"
      )
      .font(.callout.bold())
      .foregroundStyle(Color.MeetPR.textPrimary)
      ProgressView(value: presentation.progress).tint(Color.MeetPR.goldCTA)
      Text(StudentStrings.localized(.videoCompletionBody))
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(MeetPRSpacing.space4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.control))
    .accessibilityIdentifier("videoCompletion.progress")
  }
}
