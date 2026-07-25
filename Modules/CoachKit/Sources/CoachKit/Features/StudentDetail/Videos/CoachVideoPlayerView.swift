import AVKit
import DesignSystem
import SwiftUI

/// Full-screen playback of one student set video via a short-lived presigned
/// URL (spec 029 §2.6). Playback speed cycles 0.5/1/1.5/2 — coaches scrub
/// technique at half speed.
///
/// Reskinned to the `DKCoachVideoFeedback` mock's video surface: a pure black
/// stage with house-token chrome — a circular close control top-left, an
/// Eyebrow "视频回放 //" tag, and a bordered mono rate capsule top-right. The
/// expiry-retry overlay is rebuilt as a card surface (Color.MeetPR.surfaceCard +
/// border, MeetPRRadius.lg). All AVPlayer behavior — playback, rate cycling
/// via `defaultRate`, the presigned-URL re-exchange on item failure, and the
/// two failure publishers — is preserved verbatim.
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

      chrome
    }
    .background(Color.black)
    .overlay {
      if playbackFailed {
        failureCard
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

  // MARK: - Top chrome (close · tag · rate capsule)

  private var chrome: some View {
    HStack(alignment: .center) {
      Button {
        player.pause()
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay { Circle().stroke(Color.white.opacity(0.18), lineWidth: 1) }
      }
      .accessibilityLabel("关闭播放")

      Eyebrow("视频回放 //", color: .white.opacity(0.85))
        .padding(.leading, MeetPRSpacing.xs)

      Spacer()

      Button {
        cycleRate()
      } label: {
        Text(Self.rateText(rate))
          .font(
            .MeetPR.system(size: MeetPRFontMetrics.size14, weight: .semibold, design: .monospaced)
          )
          .foregroundStyle(.white)
          .padding(.horizontal, MeetPRSpacing.md)
          .frame(height: 36)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay { Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1) }
      }
      .accessibilityLabel("播放速度 \(Self.rateText(rate))")
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
  }

  // MARK: - Expiry retry overlay

  private var failureCard: some View {
    VStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size26))
        .foregroundStyle(Color.MeetPR.gold500)
      Text("播放失败，链接可能已过期")
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .multilineTextAlignment(.center)
      Button {
        retrying = true
        Task {
          defer { retrying = false }
          guard let fresh = try? await refreshURL(videoID) else { return }
          playbackFailed = false
          player.replaceCurrentItem(with: AVPlayerItem(url: fresh))
          player.defaultRate = rate
          player.play()
        }
      } label: {
        Text(retrying ? "刷新中…" : "重试")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(Color.MeetPR.gold500)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
      .buttonStyle(PressScaleButtonStyle())
      .disabled(retrying)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: 280)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg).stroke(
        Color.MeetPR.borderDefault, lineWidth: 1)
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
