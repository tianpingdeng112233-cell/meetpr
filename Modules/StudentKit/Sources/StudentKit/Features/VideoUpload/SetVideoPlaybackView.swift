import ChatUI
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct SetVideoPlaybackView: View {
  let attachmentID: UUID
  let source: VideoAttachmentPlaybackSource
  let refreshRemoteURL: @MainActor (UUID) async throws -> URL

  var body: some View {
    FeedbackVideoPlayerView(
      videoID: attachmentID,
      url: source.url,
      markers: nil,
      refreshURL: { attachmentID in
        try await source.retryURL(
          attachmentID: attachmentID,
          refreshRemoteURL: refreshRemoteURL
        )
      }
    )
  }
}
