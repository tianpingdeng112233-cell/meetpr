import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct FeedbackDetailView: View {
  let item: CoachFeedback
  private let viewModel: FeedbackInboxViewModel?

  @State private var playbackItem: FeedbackVideoPlaybackItem?
  @State private var resolvingPlayback = false
  @State private var playbackError: String?

  public init(item: CoachFeedback, viewModel: FeedbackInboxViewModel? = nil) {
    self.item = item
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          Image(systemName: "person.crop.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.MeetPR.gold500)
          VStack(alignment: .leading, spacing: 2) {
            Text(StudentStrings.localized(.feedbackDetailView001))
              .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text(StudentFormatting.dayMonth(item.postedAt))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
              .foregroundStyle(Color.MeetPR.textMuted)
          }
        }

        if let dayDate = item.dayDate {
          Label(
            StudentStrings.localized(.feedbackDetailView002) + StudentFormatting.dayMonth(dayDate),
            systemImage: "calendar"
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.textSecondary)
        }

        switch FeedbackVideoPresentation.association(videoID: item.videoID, video: item.video) {
        case .available(let video):
          // No view model means no way to sign a playback URL, so show the clip
          // as context rather than a button that is guaranteed to fail. Both
          // production entry points inject one; this keeps the public
          // initializer from being able to build a dead tap target.
          FeedbackVideoCard(
            video: video,
            isLoading: resolvingPlayback,
            action: viewModel == nil
              ? nil
              : {
                play(video: video, videoID: item.videoID ?? video.id)
              }
          )
        case .unavailable:
          FeedbackVideoUnavailableCard()
        case .none:
          EmptyView()
        }

        if let playbackError {
          Label(playbackError, systemImage: "exclamationmark.triangle")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.dangerMuted)
        }

        Text(item.text)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color.MeetPR.surfaceCard)
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: 12))
      }
      .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(StudentStrings.localized(.feedbackDetailView003))
    #if os(iOS)
      .fullScreenCover(item: $playbackItem) { playback in
        FeedbackVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          markers: playback.markers,
          badge: playback.badge,
          markersFailed: playback.markersFailed,
          onSeek: { _ in },
          onMarkersRefresh: { await refreshMarkers(videoID: playback.id) },
          refreshURL: { try await freshPlaybackURL(videoID: $0) }
        )
      }
    #else
      .sheet(item: $playbackItem) { playback in
        FeedbackVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          markers: playback.markers,
          badge: playback.badge,
          markersFailed: playback.markersFailed,
          onSeek: { _ in },
          onMarkersRefresh: { await refreshMarkers(videoID: playback.id) },
          refreshURL: { try await freshPlaybackURL(videoID: $0) }
        )
      }
    #endif
  }

  private func play(video: CoachFeedbackVideo, videoID: UUID) {
    guard !resolvingPlayback else { return }
    resolvingPlayback = true
    playbackError = nil
    Task {
      // The player opens as soon as the signed URL resolves; a slow or dead
      // marker endpoint must never delay playback (optional-surface contract).
      do {
        let url = try await freshPlaybackURL(videoID: videoID)
        playbackItem = FeedbackVideoPlaybackItem(
          id: videoID,
          url: url,
          badge: FeedbackVideoPresentation.badge(video)
        )
      } catch {
        playbackError = StudentStrings.localized(.feedbackDetailView004)
        resolvingPlayback = false
        return
      }
      resolvingPlayback = false
      await refreshMarkers(videoID: videoID)
    }
  }

  private func freshPlaybackURL(videoID: UUID) async throws -> URL {
    guard let viewModel else {
      throw FeedbackVideoPlaybackError.unavailable
    }
    return try await viewModel.playbackURL(videoID: videoID)
  }

  private func freshMarkers(videoID: UUID) async -> VideoMarkerLoadOutcome {
    guard let viewModel else { return .hidden }
    return await viewModel.markers(videoID: videoID)
  }

  private func refreshMarkers(videoID: UUID) async {
    let outcome = await freshMarkers(videoID: videoID)
    guard playbackItem?.id == videoID else { return }
    switch outcome {
    case .loaded(let markers):
      playbackItem?.markers = markers
      playbackItem?.markersFailed = false
    case .failed:
      playbackItem?.markersFailed = true
    case .hidden:
      playbackItem?.markers = nil
      playbackItem?.markersFailed = false
    }
  }
}

private struct FeedbackVideoCard: View {
  let video: CoachFeedbackVideo
  let isLoading: Bool
  /// `nil` renders the clip as context only — see the call site.
  let action: (() -> Void)?

  /// A clip with no set log has nothing to summarize; name the thing itself
  /// rather than render an empty line under the label.
  private var displaySummary: String {
    let summary = FeedbackVideoPresentation.summary(video)
    return summary.isEmpty ? StudentStrings.localized(.feedbackDetailView005) : summary
  }

  /// Context-only cards must not promise playback to VoiceOver.
  private var accessibilityText: String {
    action == nil
      ? StudentStrings.replacing(.feedbackDetailView006, values: ["\(displaySummary)"])
      : StudentStrings.replacing(.feedbackDetailView007, values: ["\(displaySummary)"])
  }

  var body: some View {
    Button(action: action ?? {}) {
      HStack(spacing: 12) {
        if isLoading {
          ProgressView()
        } else {
          Image(systemName: "play.rectangle.fill")
            .font(.title2)
            .foregroundStyle(Color.MeetPR.gold500)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(StudentStrings.localized(.feedbackDetailView008))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.textMuted)
          Text(displaySummary)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        if action != nil {
          Image(systemName: "chevron.right")
            .font(.system(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
    }
    .disabled(isLoading || action == nil)
    .accessibilityLabel(accessibilityText)
  }
}

private struct FeedbackVideoUnavailableCard: View {
  var body: some View {
    Label(StudentStrings.localized(.feedbackDetailView009), systemImage: "video.slash")
      .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}

struct FeedbackVideoPlaybackItem: Identifiable, Equatable, Sendable {
  let id: UUID
  let url: URL
  let badge: VideoBadgeInfo?
  var markers: [VideoMarker]?
  var markersFailed = false
}

enum FeedbackVideoPlaybackError: Error, Equatable, Sendable {
  case unavailable
}
