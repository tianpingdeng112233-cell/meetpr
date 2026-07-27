import AVKit
import DesignSystem
import SwiftUI

/// Full-screen student playback backed by a short-lived presigned URL.
/// A failed player item can exchange a fresh URL and retry without leaving.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentFeedbackVideoPlayerView: View {
  private static let rates: [Float] = [0.5, 1.0, 1.5, 2.0]

  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer
  @State private var rate: Float = 1.0
  @State private var playbackFailed = false
  @State private var retrying = false

  private let videoID: UUID
  private let refreshURL: (UUID) async throws -> URL

  init(videoID: UUID, url: URL, refreshURL: @escaping (UUID) async throws -> URL) {
    self.videoID = videoID
    self.refreshURL = refreshURL
    _player = State(initialValue: AVPlayer(url: url))
  }

  var body: some View {
    ZStack(alignment: .top) {
      VideoPlayer(player: player)
        .ignoresSafeArea()

      StudentFeedbackVideoPlayerChrome(
        rateText: Self.rateText(rate),
        close: close,
        cycleRate: cycleRate
      )
    }
    .background(Color.black)
    .overlay {
      if playbackFailed {
        StudentFeedbackVideoFailureCard(retrying: retrying, retry: retry)
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)
    ) { _ in
      playbackFailed = true
    }
    .onReceive(player.publisher(for: \.currentItem?.status).removeDuplicates()) { status in
      if status == .failed { playbackFailed = true }
    }
    .onAppear { player.play() }
    .onDisappear { player.pause() }
  }

  private func close() {
    player.pause()
    dismiss()
  }

  private func retry() {
    retrying = true
    Task {
      defer { retrying = false }
      guard let fresh = try? await refreshURL(videoID) else { return }
      playbackFailed = false
      player.replaceCurrentItem(with: AVPlayerItem(url: fresh))
      player.defaultRate = rate
      player.play()
    }
  }

  private func cycleRate() {
    let index = Self.rates.firstIndex(of: rate) ?? 1
    rate = Self.rates[(index + 1) % Self.rates.count]
    player.defaultRate = rate
    if player.timeControlStatus == .playing {
      player.rate = rate
    }
  }

  static func rateText(_ rate: Float) -> String {
    switch rate {
    case 0.5: "0.5x"
    case 1.5: "1.5x"
    case 2: "2x"
    default: "1x"
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct StudentFeedbackVideoPlayerChrome: View {
  let rateText: String
  let close: () -> Void
  let cycleRate: () -> Void

  var body: some View {
    HStack {
      Button(action: close) {
        Image(systemName: "xmark")
          .bold()
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay { Circle().stroke(Color.white.opacity(0.18), lineWidth: 1) }
      }
      .accessibilityLabel("关闭播放")

      Eyebrow("视频回放 //", color: .white.opacity(0.85))
        .padding(.leading, MeetPRSpacing.xs)

      Spacer()

      Button(action: cycleRate) {
        Text(rateText)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, MeetPRSpacing.md)
          .frame(height: 36)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay { Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1) }
      }
      .accessibilityLabel("播放速度 \(rateText)")
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct StudentFeedbackVideoFailureCard: View {
  let retrying: Bool
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 26))
        .foregroundStyle(Color.MeetPR.danger)
      Text("播放失败，链接可能已过期")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .multilineTextAlignment(.center)
      Button(action: retry) {
        Text(retrying ? "刷新中…" : "重试")
          .font(.MeetPR.display(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.ctaText)
          .frame(maxWidth: .infinity)
          .frame(height: MeetPRSpacing.point52)
          .background(Color.MeetPR.ctaBackground)
          .clipShape(.capsule)
      }
      .buttonStyle(.plain)
      .disabled(retrying)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: 280)
    .background(Color.MeetPR.surfaceElevated)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }
}
