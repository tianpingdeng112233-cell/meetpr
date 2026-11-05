import DesignSystem
import SwiftUI

struct SetSyncCompletionControl: View {
  var coordinator: SetSyncCompletionCoordinator?
  let onComplete: () -> Void

  var body: some View {
    switch coordinator?.phase ?? .idle {
    case .idle:
      HoldToCompleteButton(action: onComplete)
    case .syncing:
      HStack(spacing: MeetPRSpacing.space2) {
        ProgressView().tint(Color.MeetPR.inkOnCTAFill)
        Text(StudentStrings.localized(.setSyncUploading)).bold()
      }
      .font(.body)
      .foregroundStyle(Color.MeetPR.inkOnCTAFill)
      .frame(maxWidth: .infinity)
      .frame(height: MeetPRSpacing.completionControlHeight)
      .background(Color.MeetPR.holdTrack, in: .capsule)
      .accessibilityIdentifier("setSync.syncing")
    case .failed:
      VStack(spacing: MeetPRSpacing.space3) {
        HStack(alignment: .top, spacing: MeetPRSpacing.space2) {
          Image(systemName: "exclamationmark.triangle.fill")
          VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
            Text(StudentStrings.localized(.setSyncFailedTitle)).bold()
            Text(StudentStrings.localized(.setSyncFailedBody)).font(.subheadline)
              .foregroundStyle(Color.MeetPR.textSecondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .foregroundStyle(Color.MeetPR.failure)
        .padding(MeetPRSpacing.space4)
        .background(Color.MeetPR.failureSoft, in: .rect(cornerRadius: MeetPRRadius.control))
        Button(StudentStrings.localized(.setSyncRetry), action: onComplete)
          .font(.body).bold()
          .frame(maxWidth: .infinity)
          .frame(height: MeetPRSpacing.completionControlHeight)
          .foregroundStyle(Color.MeetPR.inkOnGold)
          .background(Color.MeetPR.goldCTA, in: .capsule)
      }
      .accessibilityIdentifier("setSync.failed")
    }
  }
}
