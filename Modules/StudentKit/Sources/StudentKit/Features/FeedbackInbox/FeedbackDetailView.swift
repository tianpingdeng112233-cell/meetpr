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
            .foregroundStyle(Color.MeetPR.brandRed)
          VStack(alignment: .leading, spacing: 2) {
            Text("教练反馈")
              .font(.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)
            Text(StudentFormatting.dayMonthFormatter.string(from: item.postedAt))
              .font(.caption)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }

        if let dayDate = item.dayDate {
          Label(
            "关联训练日 " + StudentFormatting.dayMonthFormatter.string(from: dayDate),
            systemImage: "calendar"
          )
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgSecondary)
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
            action: viewModel == nil ? nil : { play(videoID: item.videoID ?? video.id) }
          )
        case .unavailable:
          FeedbackVideoUnavailableCard()
        case .none:
          EmptyView()
        }

        if let playbackError {
          Label(playbackError, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Color.MeetPR.amber)
        }

        Text(item.text)
          .font(.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color.MeetPR.surface1)
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.MeetPR.border, lineWidth: 1)
          }
          .clipShape(.rect(cornerRadius: 12))
      }
      .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bg)
    .navigationTitle("反馈")
    #if os(iOS)
      .fullScreenCover(item: $playbackItem) { playback in
        StudentFeedbackVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          refreshURL: { try await freshPlaybackURL(videoID: $0) }
        )
      }
    #else
      .sheet(item: $playbackItem) { playback in
        StudentFeedbackVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          refreshURL: { try await freshPlaybackURL(videoID: $0) }
        )
      }
    #endif
  }

  private func play(videoID: UUID) {
    guard !resolvingPlayback else { return }
    resolvingPlayback = true
    playbackError = nil
    Task {
      defer { resolvingPlayback = false }
      do {
        playbackItem = FeedbackVideoPlaybackItem(
          id: videoID,
          url: try await freshPlaybackURL(videoID: videoID)
        )
      } catch {
        playbackError = "播放链接获取失败，请重试"
      }
    }
  }

  private func freshPlaybackURL(videoID: UUID) async throws -> URL {
    guard let viewModel else {
      throw FeedbackVideoPlaybackError.unavailable
    }
    return try await viewModel.playbackURL(videoID: videoID)
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
    return summary.isEmpty ? "训练视频" : summary
  }

  /// Context-only cards must not promise playback to VoiceOver.
  private var accessibilityText: String {
    action == nil ? "关联视频，\(displaySummary)" : "播放关联视频，\(displaySummary)"
  }

  var body: some View {
    Button(action: action ?? {}) {
      HStack(spacing: 12) {
        if isLoading {
          ProgressView()
        } else {
          Image(systemName: "play.rectangle.fill")
            .font(.title2)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text("关联视频")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          Text(displaySummary)
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        if action != nil {
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(isLoading || action == nil)
    .accessibilityLabel(accessibilityText)
  }
}

private struct FeedbackVideoUnavailableCard: View {
  var body: some View {
    Label("关联视频已不可用", systemImage: "video.slash")
      .font(.subheadline)
      .foregroundStyle(Color.MeetPR.fgSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: 12))
  }
}

struct FeedbackVideoPlaybackItem: Identifiable, Equatable, Sendable {
  let id: UUID
  let url: URL
}

enum FeedbackVideoPlaybackError: Error, Equatable, Sendable {
  case unavailable
}
