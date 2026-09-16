import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct FeedbackInboxView: View {
  private let studentID: UUID
  private let viewModel: FeedbackInboxViewModel

  @Environment(\.dismiss) private var dismiss
  @State private var playbackItem: FeedbackVideoPlaybackItem?
  @State private var resolvingVideoID: UUID?
  @State private var playbackError: String?

  public init(studentID: UUID, viewModel: FeedbackInboxViewModel) {
    self.studentID = studentID
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(spacing: 0) {
      FeedbackArchiveHeader(onBack: { dismiss() })
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
      .fullScreenCover(item: $playbackItem) { playback in
        FeedbackVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          markers: playback.markers,
          badge: playback.badge,
          markersFailed: playback.markersFailed,
          onSeek: { _ in },
          onMarkersRefresh: { await refreshMarkers(videoID: playback.id) },
          refreshURL: { try await viewModel.playbackURL(videoID: $0) }
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
          refreshURL: { try await viewModel.playbackURL(videoID: $0) }
        )
      }
    #endif
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      FeedbackArchiveSkeleton()
    case .loaded(let items):
      if items.isEmpty {
        FeedbackArchiveEmptyState()
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.point11) {
            Text(StudentStrings.replacing(.feedbackInboxView001, values: ["\(items.count)"]))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .tracking(0.44)
              .foregroundStyle(Color.MeetPR.textFaint)

            if let playbackError {
              Label(playbackError, systemImage: "exclamationmark.triangle")
                .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
                .foregroundStyle(Color.MeetPR.dangerMuted)
            }

            ForEach(items) { item in
              FeedbackArchiveCard(
                item: FeedbackArchivePresentation(item: item),
                isResolvingVideo: resolvingVideoID == item.videoID,
                detail: {
                  FeedbackDetailView(item: item, viewModel: viewModel)
                    .task { await viewModel.markRead(item) }
                },
                onPlayVideo: {
                  play(item)
                }
              )
            }
          }
          .padding(.horizontal, MeetPRSpacing.point18)
          .padding(.top, MeetPRSpacing.space4)
          .padding(.bottom, MeetPRSpacing.point28)
        }
        .scrollIndicators(.hidden)
      }
    case .error(let message):
      FeedbackArchiveErrorState(message: message) {
        Task { await viewModel.load(studentID: studentID) }
      }
    }
  }

  private func play(_ item: CoachFeedback) {
    guard
      let video = item.video,
      let videoID = item.videoID ?? Optional(video.id),
      resolvingVideoID == nil
    else { return }
    resolvingVideoID = videoID
    playbackError = nil
    Task {
      await viewModel.markRead(item)
      // The player opens as soon as the signed URL resolves; a slow or dead
      // marker endpoint must never delay playback (optional-surface contract).
      do {
        let url = try await viewModel.playbackURL(videoID: videoID)
        playbackItem = FeedbackVideoPlaybackItem(
          id: videoID,
          url: url,
          badge: FeedbackVideoPresentation.badge(video)
        )
      } catch {
        playbackError = StudentStrings.localized(.feedbackInboxView002)
        resolvingVideoID = nil
        return
      }
      resolvingVideoID = nil
      await refreshMarkers(videoID: videoID)
    }
  }

  private func refreshMarkers(videoID: UUID) async {
    let outcome = await viewModel.markers(videoID: videoID)
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

private struct FeedbackArchivePresentation: Equatable, Sendable, Identifiable {
  let item: CoachFeedback
  let durationText: String?

  init(item: CoachFeedback, durationText: String? = nil) {
    self.item = item
    self.durationText = durationText
  }

  var id: UUID { item.id }
  var isUnread: Bool { item.readAt == nil }
  var label: String {
    item.video.flatMap { StudentExerciseName.display($0) }
      ?? StudentStrings.localized(.feedbackInboxView003)
  }

  var dateText: String {
    if Calendar.current.isDateInToday(item.postedAt) {
      return StudentStrings.localized(.feedbackInboxView004)
    }
    return StudentFormatting.numericMonthDay(item.postedAt)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackArchiveHeader: View {
  let onBack: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Button(action: onBack) {
        Image(systemName: "chevron.left")
          .font(.system(size: MeetPRFontMetrics.size20, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
          .background(Color.MeetPR.surfaceCard, in: .circle)
          .frame(
            width: MeetPRSpacing.minimumHitTarget,
            height: MeetPRSpacing.minimumHitTarget
          )
      }
      .buttonStyle(PressScaleButtonStyle())
      .accessibilityLabel(StudentStrings.localized(.feedbackInboxView005))

      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(StudentStrings.localized(.feedbackInboxView006))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(StudentStrings.localized(.feedbackInboxView007))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      Spacer()
    }
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.top, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.point14)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackArchiveCard<Detail: View>: View {
  let item: FeedbackArchivePresentation
  let isResolvingVideo: Bool
  @ViewBuilder let detail: Detail
  let onPlayVideo: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      NavigationLink {
        detail
      } label: {
        VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
          HStack(spacing: MeetPRSpacing.point7) {
            if item.isUnread {
              Circle()
                .fill(Color.MeetPR.gold500)
                .frame(width: MeetPRSpacing.point7, height: MeetPRSpacing.point7)
            }
            Text(item.label)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Spacer()
            Text(item.dateText)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textFaint)
          }

          Text(item.item.text)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineSpacing(MeetPRSpacing.point5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }

      if case .available(let video) = FeedbackVideoPresentation.association(
        videoID: item.item.videoID,
        video: item.item.video
      ) {
        Button(action: onPlayVideo) {
          HStack(spacing: MeetPRSpacing.point10) {
            ZStack {
              LinearGradient(
                colors: [.MeetPR.borderStrong, .MeetPR.surfaceCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
              if isResolvingVideo {
                ProgressView()
                  .tint(.white)
                  .scaleEffect(0.7)
              } else {
                Image(systemName: "play.fill")
                  .font(.system(size: MeetPRFontMetrics.size12))
                  .foregroundStyle(Color.white)
              }
            }
            .frame(width: MeetPRSpacing.point30, height: MeetPRSpacing.point30)
            .clipShape(.rect(cornerRadius: MeetPRSpacing.space2))

            VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
              Text(StudentStrings.localized(.feedbackInboxView008))
                .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
                .foregroundStyle(Color.MeetPR.textSecondary)
              let summary = FeedbackVideoPresentation.summary(video)
              if !summary.isEmpty {
                Text(summary)
                  .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
                  .foregroundStyle(Color.MeetPR.textFaint)
                  .lineLimit(1)
              }
            }

            Spacer(minLength: 0)

            if let durationText = item.durationText {
              Text(durationText)
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
                .foregroundStyle(Color.MeetPR.textFaint)
            }
          }
          .padding(.horizontal, MeetPRSpacing.point11)
          .padding(.vertical, MeetPRSpacing.space2)
          .background(Color.MeetPR.bgInset)
          .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
        }
        .disabled(isResolvingVideo)
        .padding(.top, MeetPRSpacing.point11)
      }
    }
    .padding(.horizontal, MeetPRSpacing.point15)
    .padding(.vertical, MeetPRSpacing.point13)
    .background {
      ZStack(alignment: .leading) {
        Color.MeetPR.surfaceCard
        Rectangle()
          .fill(item.isUnread ? Color.MeetPR.gold500 : Color.MeetPR.borderStrong)
          .frame(width: MeetPRSpacing.point3)
      }
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
  }
}

private struct FeedbackArchiveSkeleton: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.point11) {
      ForEach(0..<4, id: \.self) { _ in
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .fill(Color.MeetPR.textGhost.opacity(0.3))
          .frame(height: 126)
      }
      Spacer()
    }
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.top, MeetPRSpacing.space4)
    .accessibilityLabel(StudentStrings.localized(.feedbackInboxView009))
  }
}

private struct FeedbackArchiveEmptyState: View {
  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Image(systemName: "bubble.left")
        .font(.system(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textDim)
      Text(StudentStrings.localized(.feedbackInboxView010))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct FeedbackArchiveErrorState: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.space3) {
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .multilineTextAlignment(.center)
      Button(StudentStrings.localized(.feedbackInboxView011), action: retry)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.goldText)
        .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .padding(MeetPRSpacing.space5)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
