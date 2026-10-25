import CoreModels
import DesignSystem
import SwiftUI

struct CompletedVideoReplayView: View {
  let model: CompletedVideoReplayModel
  let request: CompletedVideoReplayModel.Request
  @State private var playback = SetEntryVideoPlayer(preservesPlaybackIntentOnFailure: true)
  @State private var errorMessage: String?
  @State private var showsReview = false
  @State private var automaticallyRetried = false
  @State private var isRefreshing = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if let errorMessage {
          ContentUnavailableView {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
          } actions: {
            Button(StudentStrings.localized(.videoAttachmentSection002)) {
              Task { await load() }
            }
            Button(StudentStrings.localized(.setEntryVideoCollapse)) { dismiss() }
          }
        } else {
          SetEntryVideoPlayerView(
            playback: playback, badge: request.badge, readOnly: true,
            showsPlaybackError: automaticallyRetried && !isRefreshing,
            onClose: { dismiss() },
            onReview: model.review(for: request.video) == nil
              ? nil
              : {
                if playback.state.isPlaying { playback.togglePlayback() }
                showsReview = true
              }, retry: { Task { await retry() } })
        }
      }
      .background(.black)
      #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
      #endif
      .navigationDestination(isPresented: $showsReview) {
        if let review = model.review(for: request.video) {
          FeedbackDetailView(item: review, viewModel: model.feedback)
            #if os(iOS)
              .toolbar(.visible, for: .navigationBar)
            #endif
        }
      }
    }
    .task { await load() }
    .onChange(of: playback.hasError) { _, failed in
      guard failed, !automaticallyRetried else { return }
      automaticallyRetried = true
      Task { await retry() }
    }
    .onDisappear { playback.stop() }
  }

  private func load() async {
    errorMessage = nil
    do {
      let source = try await model.source(for: request.video)
      try Task.checkCancellation()
      playback.load(attachmentID: request.id, source: source)
      if !playback.state.isExpanded { playback.state.toggleExpanded() }
      playback.togglePlayback()
    } catch {
      guard !error.isTaskCancellation else { return }
      errorMessage = StudentStrings.localized(.videoAttachmentSection004)
    }
  }

  private func retry() async {
    isRefreshing = true
    defer { isRefreshing = false }
    await playback.retry { _ in try await model.freshURL(for: request.video) }
  }
}
