import ChatUI
import DesignSystem
import SwiftUI

/// Reuses the durable attachment pipeline without exposing the retired set-entry form.
struct AllDayVideoSheet: View {
  let draft: TodayWorkoutSetRowDraft
  let viewModel: TodayWorkoutViewModel
  let studentID: UUID
  let trainingDate: Date
  let videoViewModel: VideoAttachmentViewModel
  @State private var playback = SetEntryVideoPlayer()
  @Environment(\.dismiss) private var dismiss

  private var currentBadge: VideoBadgeInfo {
    (viewModel.currentDrafts?.first { $0.id == draft.id } ?? draft).videoBadge
  }

  var body: some View {
    NavigationStack {
      VideoAttachmentSection(
        draftID: draft.id, slot: draft.pendingVideoSlot, studentID: studentID,
        trainingDate: trainingDate, videoViewModel: videoViewModel,
        badge: currentBadge, playback: playback, initialSetLogID: draft.loggedSetID,
        resolveSetLogID: {
          await viewModel.resolveVideoSetLogID(draftID: draft.id, trainingDate: trainingDate)
        }
      )
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.bgBase)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(DesignSystemStrings.done) { dismiss() }
        }
      }
    }
    .interactiveDismissDisabled(playback.state.isExpanded)
    .overlay {
      if playback.state.isExpanded {
        SetEntryVideoPlayerView(playback: playback, badge: currentBadge) {
          Task {
            await playback.retry { attachmentID in
              try await videoViewModel.freshRemotePlaybackURL(attachmentID: attachmentID)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
      }
    }
    .onDisappear { playback.stop() }
  }
}
