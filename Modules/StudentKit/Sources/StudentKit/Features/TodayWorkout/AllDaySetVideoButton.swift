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

  private var rowState: VideoAttachmentViewModel.RowState? {
    uploads?.pendingRowState(
      draftID: draft.id, trainingDate: trainingDate, slot: draft.pendingVideoSlot)
      ?? draft.loggedSetID.flatMap { uploads?.rowStates[$0] }
  }

  private var attachment: VideoAttachment? {
    rowState?.attachment
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

  private var observedTransfer: VideoAttachment? {
    guard let live = rowState?.attachment, live.status == .uploading,
      live.uploadGeneration != nil, live.remoteAttachmentID != nil
    else { return nil }
    return live
  }

  private var fillFraction: Double? {
    guard status == .uploading || status == .pending else { return nil }
    if attachment?.status == .uploaded { return 1 }
    if let rowState { return rowState.progress }
    let partSize =
      uploads?.manager.configuration.partSizeBytes
      ?? VideoUploadConfiguration.default.partSizeBytes
    return attachment?.uploadFraction(partSize: partSize) ?? 0
  }

  var body: some View {
    if editable || status != nil {
      Button(action: openVideo) {
        Image(systemName: status == .uploaded ? "video.fill" : "video")
          .foregroundStyle(color)
          .overlay {
            if let fillFraction {
              Image(systemName: "video.fill")
                .foregroundStyle(color)
                .mask { Rectangle().scaleEffect(y: fillFraction, anchor: .bottom) }
            }
          }
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
          .frame(width: 40, height: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.plain)
      .disabled(!editable && video == nil && status != .failed)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityValue(
        Text(verbatim: fillFraction?.formatted(.percent.precision(.fractionLength(0))) ?? "")
      )
      .task(id: observedTransfer?.remoteAttachmentID) {
        if let observedTransfer { await uploads?.observeTransfer(of: observedTransfer) }
      }
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
