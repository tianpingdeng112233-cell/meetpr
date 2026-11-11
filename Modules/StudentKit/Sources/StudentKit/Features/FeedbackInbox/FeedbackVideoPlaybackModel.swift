import CoreModels
import Foundation
import Observation

/// Playback state shared by the chat's video covers and its full-screen presenter.
@MainActor @Observable
final class FeedbackVideoPlaybackModel {
  var selection: FeedbackVideoPlaybackItem?
  private(set) var resolvingFeedbackID: UUID?
  private(set) var failedFeedbackID: UUID?
  private var requestID = UUID()
  private let feedback: FeedbackInboxViewModel

  init(feedback: FeedbackInboxViewModel) {
    self.feedback = feedback
  }

  func open(_ item: CoachFeedback) async {
    guard resolvingFeedbackID == nil, let videoID = item.videoID, let video = item.video else {
      return
    }
    let request = UUID()
    requestID = request
    resolvingFeedbackID = item.id
    failedFeedbackID = nil
    defer {
      if requestID == request { resolvingFeedbackID = nil }
    }
    do {
      let url = try await feedback.playbackURL(videoID: videoID)
      guard requestID == request, !Task.isCancelled else { return }
      selection = FeedbackVideoPlaybackItem(
        id: videoID, url: url, badge: FeedbackVideoPresentation.badge(video))
    } catch {
      guard requestID == request, !error.isTaskCancellation else { return }
      failedFeedbackID = item.id
    }
  }

  func cancel() {
    requestID = UUID()
    resolvingFeedbackID = nil
    failedFeedbackID = nil
    selection = nil
  }

  func freshURL(videoID: UUID) async throws -> URL {
    try await feedback.playbackURL(videoID: videoID)
  }

  func refreshMarkers(videoID: UUID) async {
    let request = requestID
    let outcome = await feedback.markers(videoID: videoID)
    guard requestID == request, !Task.isCancelled, selection?.id == videoID else { return }
    switch outcome {
    case .loaded(let markers):
      selection?.markers = markers
      selection?.markersFailed = false
    case .failed:
      selection?.markersFailed = true
    case .hidden:
      selection?.markers = nil
      selection?.markersFailed = false
    }
  }

}
