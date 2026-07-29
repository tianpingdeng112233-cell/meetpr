import ChatUI
import SwiftUI

/// Keeps the existing coach feedback call sites on one semantic name while the
/// player implementation is shared with chat set cards.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachVideoPlayerView: View {
  private let videoID: UUID
  private let url: URL
  private let refreshURL: @MainActor (UUID) async throws -> URL

  init(
    videoID: UUID,
    url: URL,
    refreshURL: @escaping @MainActor (UUID) async throws -> URL
  ) {
    self.videoID = videoID
    self.url = url
    self.refreshURL = refreshURL
  }

  var body: some View {
    FeedbackVideoPlayerView(
      videoID: videoID,
      url: url,
      refreshURL: refreshURL
    )
  }
}
