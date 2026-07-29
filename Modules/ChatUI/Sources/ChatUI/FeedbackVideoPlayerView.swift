import AVKit
import DesignSystem
import SwiftUI

/// Shared full-screen player for coach feedback and chat set-card videos.
///
/// Presigned URLs can expire while the player is open. Both item-failure
/// signals expose the same retry surface, which asks the caller to exchange a
/// fresh URL before replacing the player item.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct FeedbackVideoPlayerView: View {
  private static let rates: [Float] = [0.5, 1.0, 1.5, 2.0]

  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer
  @State private var rate: Float = 1.0
  @State private var playbackFailed = false
  @State private var retrying = false

  private let videoID: UUID
  private let refreshURL: @MainActor (UUID) async throws -> URL

  public init(
    videoID: UUID,
    url: URL,
    refreshURL: @escaping @MainActor (UUID) async throws -> URL
  ) {
    self.videoID = videoID
    self.refreshURL = refreshURL
    _player = State(initialValue: AVPlayer(url: url))
  }

  public var body: some View {
    ZStack(alignment: .top) {
      VideoPlayer(player: player)
        .ignoresSafeArea()

      FeedbackVideoPlayerChrome(
        rateText: Self.rateText(rate),
        close: close,
        cycleRate: cycleRate
      )
    }
    .background(Color.black)
    .overlay {
      if playbackFailed {
        FeedbackVideoFailureCard(retrying: retrying, retry: retry)
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)
    ) { _ in
      playbackFailed = true
    }
    .onReceive(player.publisher(for: \.currentItem?.status).removeDuplicates()) { status in
      if status == .failed {
        playbackFailed = true
      }
    }
    .onAppear {
      player.play()
    }
    .onDisappear {
      player.pause()
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

  private func close() {
    player.pause()
    dismiss()
  }

  private func retry() {
    retrying = true
    Task {
      defer { retrying = false }
      guard let fresh = try? await refreshURL(videoID) else {
        return
      }
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
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackVideoPlayerChrome: View {
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
          .overlay {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
          }
      }
      .accessibilityLabel(ChatStrings.closePlayback)

      Eyebrow(ChatStrings.videoPlayback, color: .white.opacity(0.85))
        .padding(.leading, MeetPRSpacing.xs)

      Spacer()

      Button(action: cycleRate) {
        Text(rateText)
          .font(.system(size: 14, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white)
          .padding(.horizontal, MeetPRSpacing.md)
          .frame(height: 36)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay {
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
          }
      }
      .accessibilityLabel("\(ChatStrings.playbackSpeed) \(rateText)")
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct FeedbackVideoFailureCard: View {
  let retrying: Bool
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 26))
        .foregroundStyle(Color.MeetPR.amber)
      Text(ChatStrings.playbackFailed)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .multilineTextAlignment(.center)
      Button(action: retry) {
        Text(retrying ? ChatStrings.refreshing : ChatStrings.retry)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(Color.MeetPR.goldCTA)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
      .buttonStyle(.plain)
      .disabled(retrying)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: 280)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }
}
