import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// One pending video opened from the 训练视频 inbox (spec 042): play the clip
/// full screen, then write text feedback. Visually aligned to
/// `FeedbackComposerView` but scoped to the video — no day / exercise pickers,
/// since the video already implies the student, day, and exercise.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoFeedbackDetailView: View {
  private let item: PendingVideoItem
  private let viewModel: CoachVideoQueueViewModel
  private let onSent: () -> Void

  @State private var text = ""
  @State private var playbackItem: StudentVideoPlaybackItem?
  @State private var resolvingPlayback = false
  @State private var playbackError: String?
  @State private var sending = false
  @Environment(\.dismiss) private var dismiss

  init(
    item: PendingVideoItem,
    viewModel: CoachVideoQueueViewModel,
    onSent: @escaping () -> Void = {}
  ) {
    self.item = item
    self.viewModel = viewModel
    self.onSent = onSent
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: MeetPRSpacing.zero) {
        header

        ScrollView {
          VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
            videoCard
            editorCard
            if let playbackError {
              banner(playbackError)
            }
            if let banner = viewModel.bannerMessage {
              self.banner(banner)
            }
          }
          .padding(MeetPRSpacing.base)
        }
        .scrollContentBackground(.hidden)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .safeAreaInset(edge: .bottom) { sendBar }
    }
    #if os(iOS)
      .fullScreenCover(item: $playbackItem) { playback in
        CoachVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          refreshURL: { try await viewModel.playbackURL(videoID: $0) }
        )
      }
    #else
      .sheet(item: $playbackItem) { playback in
        CoachVideoPlayerView(
          videoID: playback.id,
          url: playback.url,
          refreshURL: { try await viewModel.playbackURL(videoID: $0) }
        )
      }
    #endif
  }

  // MARK: - Header (cancel · student name)

  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      HStack {
        Eyebrow("视频反馈 //")
        Spacer()
        Button("取消") { dismiss() }
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      Text("给 \(item.studentDisplayName) 写反馈")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size28, weight: .heavy))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.xs)
  }

  // MARK: - Video card (meta + play)

  private var videoCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      sectionLabel("训练视频")
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Text(metaLine)
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14, design: .monospaced))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Button(action: play) {
          HStack(spacing: MeetPRSpacing.sm) {
            if resolvingPlayback {
              ProgressView()
            } else {
              Image(systemName: "play.rectangle.fill")
                .foregroundStyle(Color.MeetPR.gold500)
            }
            Text(resolvingPlayback ? "加载中…" : "播放视频")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, MeetPRSpacing.md)
          .padding(.horizontal, MeetPRSpacing.base)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(resolvingPlayback)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
  }

  private var metaLine: String {
    var parts: [String] = []
    if let exerciseName = item.exerciseName { parts.append(exerciseName) }
    parts.append(CoachStudentFormatting.fullDateText(item.uploadedAt))
    parts.append(Self.sizeText(item.sizeBytes))
    return parts.joined(separator: " · ")
  }

  // MARK: - Editor card

  private var editorCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      sectionLabel("反馈内容")
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text("给 \(item.studentDisplayName) 写反馈...")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.textTertiary)
            .padding(.top, MeetPRSpacing.space2)
            .padding(.leading, MeetPRSpacing.point5)
        }
        TextEditor(text: $text)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.textPrimary)
          .scrollContentBackground(.hidden)
      }
      .frame(minHeight: 160)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
    }
  }

  private func banner(_ message: String) -> some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .font(Font.MeetPR.footnote)
      .foregroundStyle(Color.MeetPR.gold500)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.goldSoft)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  // MARK: - Send bar

  private var sendBar: some View {
    Button(action: send) {
      HStack(spacing: MeetPRSpacing.sm) {
        Image(systemName: "paperplane.fill")
        Text("发送")
      }
      .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
      .foregroundStyle(canSend ? Color.MeetPR.bgBase : Color.MeetPR.textTertiary)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(canSend ? Color.MeetPR.textPrimary : Color.MeetPR.surfaceElevated)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(!canSend)
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(.ultraThinMaterial)
    .accessibilityLabel("发送")
  }

  private var canSend: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
  }

  // MARK: - Actions

  private func play() {
    guard !resolvingPlayback else { return }
    resolvingPlayback = true
    playbackError = nil
    Task {
      defer { resolvingPlayback = false }
      do {
        let url = try await viewModel.playbackURL(videoID: item.id)
        playbackItem = StudentVideoPlaybackItem(id: item.id, url: url)
      } catch {
        playbackError = "播放链接获取失败,请重试"
      }
    }
  }

  private func send() {
    guard canSend else { return }
    sending = true
    Task {
      defer { sending = false }
      if await viewModel.sendFeedback(for: item, text: text) {
        onSent()
        dismiss()
      }
    }
  }

  // MARK: - Building blocks

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  static func sizeText(_ sizeBytes: Int64) -> String {
    let megabytes = Double(sizeBytes) / 1_048_576
    if megabytes >= 10 {
      return "\(Int(megabytes.rounded())) MB"
    }
    return String(format: "%.1f MB", megabytes)
  }
}
