import AVKit
import DesignSystem
import SwiftUI

/// Full-screen playback of one student set video via a short-lived presigned
/// URL (spec 029 §2.6). Playback speed cycles 0.5/1/1.5/2 — coaches scrub
/// technique at half speed.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachVideoPlayerView: View {
  private static let rates: [Float] = [0.5, 1.0, 1.5, 2.0]

  @Environment(\.dismiss) private var dismiss
  @State private var player: AVPlayer
  @State private var rate: Float = 1.0
  @State private var playbackFailed = false
  @State private var retrying = false

  private let videoID: UUID
  /// Exchanges a fresh 15-minute playback URL — the presigned link can expire
  /// mid-session, so player-item failure re-exchanges instead of dead-ending
  /// (Codex review P1).
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
      HStack {
        Button {
          player.pause()
          dismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(Font.MeetPR.title2)
        }
        .accessibilityLabel("关闭播放")

        Spacer()

        Button {
          cycleRate()
        } label: {
          Text(Self.rateText(rate))
            .font(Font.MeetPR.bodyEmphasis)
            .padding(.horizontal, MeetPRSpacing.sm)
            .padding(.vertical, MeetPRSpacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .accessibilityLabel("播放速度 \(Self.rateText(rate))")
      }
      .foregroundStyle(.white)
      .padding(MeetPRSpacing.base)
    }
    .background(Color.black)
    .overlay {
      if playbackFailed {
        VStack(spacing: MeetPRSpacing.sm) {
          Text("播放失败，链接可能已过期")
            .font(Font.MeetPR.body)
            .foregroundStyle(.white)
          Button(retrying ? "刷新中…" : "重试") {
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
          .buttonStyle(.borderedProminent)
          .tint(Color.MeetPR.brandRed)
          .disabled(retrying)
        }
        .padding(MeetPRSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification)
    ) { _ in
      playbackFailed = true
    }
    .onReceive(
      player.publisher(for: \.currentItem?.status).removeDuplicates()
    ) { status in
      if status == .failed { playbackFailed = true }
    }
    .onAppear {
      player.play()
    }
    .onDisappear {
      player.pause()
    }
  }

  private func cycleRate() {
    let index = Self.rates.firstIndex(of: rate) ?? 1
    rate = Self.rates[(index + 1) % Self.rates.count]
    // defaultRate survives pause/play; setting `rate` alone is reset by the
    // transport controls.
    player.defaultRate = rate
    if player.timeControlStatus == .playing {
      player.rate = rate
    }
  }

  static func rateText(_ rate: Float) -> String {
    String(format: "%gx", rate)
  }
}
