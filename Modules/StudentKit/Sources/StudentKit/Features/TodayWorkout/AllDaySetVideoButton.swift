import CoreModels
import DesignSystem
import SwiftUI

/// Settling a training day removes editing, never its delivery status or replay.
struct AllDaySetVideoButton: View {
  let draft: TodayWorkoutSetRowDraft
  let trainingDate: Date
  let editable: Bool
  let uploads: VideoAttachmentViewModel?
  let replay: CompletedVideoReplayModel?
  let onEditVideo: () -> Void

  private var attachment: VideoAttachment? {
    uploads?.pendingRowState(
      draftID: draft.id, trainingDate: trainingDate, slot: draft.pendingVideoSlot)?.attachment
      ?? draft.loggedSetID.flatMap { uploads?.rowStates[$0]?.attachment }
      ?? VideoDeliveryPresentation.attachment(
        for: draft, trainingDate: trainingDate, in: replay?.local ?? [])
  }

  private var video: CompletedSetVideo? {
    guard attachment?.pendingDraftID == nil else { return nil }
    return CompletedSetVideo.resolve(
      setLogID: draft.loggedSetID, videos: replay?.videos ?? [],
      local: attachment.map { [$0] } ?? [])
  }

  private var status: VideoAttachment.Status? {
    if video != nil { return .uploaded }
    if let attachment {
      // Upload completion alone is not delivery until the video is bound to its set.
      if attachment.status == .uploaded, attachment.pendingDraftID != nil { return .pending }
      return attachment.status
    }
    return nil
  }

  var body: some View {
    if editable || status != nil {
      Button(action: openVideo) {
        Image(systemName: "video")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
          .foregroundStyle(color)
          .frame(width: 40, height: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.plain)
      .disabled(!editable && video == nil && status != .failed)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityIdentifier("allDay.camera.\(draft.id)")
    }
  }

  private var color: Color {
    switch status {
    case .uploaded: Color.MeetPR.success
    case .pending, .uploading: Color.MeetPR.gold500
    case .failed: Color.MeetPR.danger
    case nil: Color.MeetPR.textSecondary
    }
  }

  private var accessibilityLabel: String {
    switch status {
    case .uploaded: StudentStrings.localized(.setVideoUploadIndicator002)
    case .pending, .uploading:
      StudentStrings.replacing(.videoCompletionUploading, values: ["1"])
    case .failed: StudentStrings.localized(.setVideoUploadIndicator003)
    case nil: StudentStrings.localized(.setVideoUploadIndicator001)
    }
  }

  private func openVideo() {
    if editable {
      switch video {
      case .remote: break
      case .local, nil:
        onEditVideo()
        return
      }
    }
    if let video {
      let row = CompletedDayPresentation.Row(
        draft: draft, unit: .kg, videos: [], local: [], trainingDate: trainingDate)
      replay?.open(video, badge: row.badge)
    } else if status == .failed, let attachment {
      Task { await uploads?.retry(setLogID: attachment.setLogID) }
    }
  }
}
