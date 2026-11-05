import CoreModels
import DesignSystem
import SwiftUI

struct CompletedSetVideoButton: View {
  let video: CompletedSetVideo?
  let upload: VideoAttachment?
  let number: Int
  var reservesSpace = false
  let onPlay: (CompletedSetVideo) -> Void
  @Environment(VideoAttachmentViewModel.self) private var uploads: VideoAttachmentViewModel?

  var body: some View {
    if let upload, VideoDeliveryPresentation.hasFailure(upload) {
      Button {
        Task { await uploads?.retry(setLogID: upload.setLogID) }
      } label: {
        Label(
          StudentStrings.localized(.videoNotDelivered), systemImage: "exclamationmark.triangle.fill"
        )
        .font(.footnote)
        .foregroundStyle(Color.MeetPR.danger)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("completedVideo.failed.\(number)")
    } else if reservesSpace || video != nil {
      // Inherit the row's text height/baseline; the overlay owns the larger hit area.
      Text(verbatim: " ")
        .hidden()
        .accessibilityHidden(true)
        .frame(width: MeetPRFontMetrics.size18)
        .overlay {
          if let video {
            playbackButton(video)
          }
        }
    }
  }

  private func playbackButton(_ video: CompletedSetVideo) -> some View {
    Button {
      onPlay(video)
    } label: {
      Image(systemName: "play.circle")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .light))
        .foregroundStyle(Color.MeetPR.completedVideoPlay)
        .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      String(localized: "student.completedVideo.playSet \(number)", bundle: .module)
    )
    .accessibilityIdentifier("completedVideo.play.\(number)")
    .anchorPreference(key: CompletedVideoHitRegions.self, value: .bounds) { anchor in
      [number: CompletedVideoHitRegion(bounds: anchor, play: { onPlay(video) })]
    }
  }
}
