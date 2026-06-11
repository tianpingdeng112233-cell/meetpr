import CoreModels
import DesignSystem
import SwiftUI

/// Coach video wall: date-grouped grid of the student's uploaded set videos
/// (spec 029 §2.6, second pass). Metadata only — tapping a tile exchanges
/// the video id for a 15-minute presigned URL and plays it full screen.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentVideoGridView: View {
  let videos: [StudentVideo]
  let unavailable: Bool
  @Bindable private var viewModel: StudentVideoGridViewModel

  init(videos: [StudentVideo], unavailable: Bool, viewModel: StudentVideoGridViewModel) {
    self.videos = videos
    self.unavailable = unavailable
    self.viewModel = viewModel
  }

  var body: some View {
    content
      .background(Color.MeetPR.bg)
      #if os(iOS)
        .fullScreenCover(item: $viewModel.playbackItem) { item in
          CoachVideoPlayerView(url: item.url)
        }
      #else
        .sheet(item: $viewModel.playbackItem) { item in
          CoachVideoPlayerView(url: item.url)
        }
      #endif
  }

  @ViewBuilder
  private var content: some View {
    if unavailable {
      wallMessage(
        "视频加载失败",
        systemImage: "exclamationmark.triangle",
        description: "下拉刷新重试"
      )
    } else if videos.isEmpty {
      wallMessage(
        "学员还没有上传视频",
        systemImage: "video",
        description: "学员在打卡时录的视频会出现在这里"
      )
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
          if let playbackError = viewModel.playbackError {
            playbackErrorBanner(playbackError)
          }
          ForEach(StudentVideoGridViewModel.makeSections(videos: videos)) { section in
            daySection(section)
          }
        }
        .padding(MeetPRSpacing.base)
      }
    }
  }

  /// Empty/error states sit inside a ScrollView so the detail screen's
  /// pull-to-refresh retry path keeps working when there is nothing to scroll.
  private func wallMessage(
    _ title: String,
    systemImage: String,
    description: String
  ) -> some View {
    ScrollView {
      ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
        .containerRelativeFrame(.vertical)
    }
  }

  private func daySection(_ section: StudentVideoDaySection) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(CoachStudentFormatting.fullDateText(section.day))
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: MeetPRSpacing.sm), count: 3),
        spacing: MeetPRSpacing.sm
      ) {
        ForEach(section.videos) { video in
          StudentVideoTile(video: video, isLoading: viewModel.loadingVideoID == video.id) {
            Task { await viewModel.play(video) }
          }
        }
      }
    }
  }

  private func playbackErrorBanner(_ message: String) -> some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Image(systemName: "exclamationmark.triangle")
      Text(message)
        .font(Font.MeetPR.footnote)
      Spacer()
      Button("知道了") {
        viewModel.clearPlaybackError()
      }
      .font(Font.MeetPR.footnote)
    }
    .foregroundStyle(Color.MeetPR.brandRed)
    .padding(MeetPRSpacing.sm)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }
}

/// No server-side thumbnails in V0.1 (the wall is metadata-only by design),
/// so the tile is an icon + capture time + size.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct StudentVideoTile: View {
  let video: StudentVideo
  let isLoading: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: MeetPRSpacing.xs) {
        ZStack {
          Image(systemName: "play.rectangle.fill")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.brandRed)
            .opacity(isLoading ? 0 : 1)
          if isLoading {
            ProgressView()
          }
        }
        Text(CoachStudentFormatting.timeText(video.displayDate))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(Self.sizeText(video.sizeBytes))
          .font(Font.MeetPR.monoLabel)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.base)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
    .accessibilityLabel(
      "视频 \(CoachStudentFormatting.timeText(video.displayDate))，点按播放"
    )
  }

  static func sizeText(_ sizeBytes: Int64) -> String {
    let megabytes = Double(sizeBytes) / 1_048_576
    if megabytes >= 10 {
      return "\(Int(megabytes.rounded())) MB"
    }
    return String(format: "%.1f MB", megabytes)
  }
}
