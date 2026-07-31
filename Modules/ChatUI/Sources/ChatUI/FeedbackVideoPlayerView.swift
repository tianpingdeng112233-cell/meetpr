import AVKit
import CoreModels
import DesignSystem
import SwiftUI

/// Opts the shared player into the coach feedback workbench's embedded chrome.
/// Leaving this nil preserves the existing full-screen chat/player behavior.
public struct FeedbackVideoWorkbenchConfiguration: Sendable {
  public init() {}
}

enum FeedbackVideoPlaybackBehavior: Equatable, Sendable {
  case legacyFullScreen
  case workbench

  enum PlaybackCommand: Equatable, Sendable {
    case none
    case play
    case playImmediatelyAtSelectedRate
  }

  var appearanceCommand: PlaybackCommand {
    switch self {
    case .legacyFullScreen:
      return .play
    case .workbench:
      return .none
    }
  }

  var retryCommand: PlaybackCommand {
    switch self {
    case .legacyFullScreen:
      return .play
    case .workbench:
      return .playImmediatelyAtSelectedRate
    }
  }

  func appliesSelectedRate(while status: AVPlayer.TimeControlStatus) -> Bool {
    switch self {
    case .legacyFullScreen:
      return status == .playing
    case .workbench:
      return status != .paused
    }
  }
}

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
  @State private var isPlaying = false
  @State private var currentSeconds = 0.0
  @State private var durationSeconds = 0.0

  private let videoID: UUID
  private let refreshURL: @MainActor (UUID) async throws -> URL
  private let workbenchConfiguration: FeedbackVideoWorkbenchConfiguration?
  private let currentSecondsBinding: Binding<Double>?
  private let markers: [VideoMarker]?
  private let markersFailed: Bool
  private let onSeek: @MainActor (Int) -> Void
  private let onAddMarker: (@MainActor () -> Void)?

  public init(
    videoID: UUID,
    url: URL,
    workbenchConfiguration: FeedbackVideoWorkbenchConfiguration? = nil,
    currentSeconds: Binding<Double>? = nil,
    markers: [VideoMarker]? = nil,
    markersFailed: Bool = false,
    onSeek: @escaping @MainActor (Int) -> Void = { _ in },
    onAddMarker: (@MainActor () -> Void)? = nil,
    refreshURL: @escaping @MainActor (UUID) async throws -> URL
  ) {
    self.videoID = videoID
    self.refreshURL = refreshURL
    self.workbenchConfiguration = workbenchConfiguration
    currentSecondsBinding = currentSeconds
    self.markers = markers
    self.markersFailed = markersFailed
    self.onSeek = onSeek
    self.onAddMarker = onAddMarker
    _player = State(initialValue: AVPlayer(url: url))
  }

  public var body: some View {
    playerContent
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
      .onReceive(player.publisher(for: \.timeControlStatus).removeDuplicates()) { status in
        if status == .playing {
          isPlaying = true
        } else if status == .paused {
          isPlaying = false
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
      ) { notification in
        guard notification.object as? AVPlayerItem === player.currentItem else { return }
        isPlaying = false
      }
      .onAppear {
        switch playbackBehavior.appearanceCommand {
        case .none:
          player.defaultRate = rate
        case .play:
          player.play()
        case .playImmediatelyAtSelectedRate:
          player.playImmediately(atRate: rate)
        }
      }
      .onDisappear {
        player.pause()
      }
      .task {
        guard
          workbenchConfiguration != nil || markers != nil || markersFailed
            || currentSecondsBinding != nil
        else {
          return
        }
        while !Task.isCancelled {
          updateTimeline()
          try? await Task.sleep(for: .milliseconds(250))
        }
      }
  }

  private var playbackBehavior: FeedbackVideoPlaybackBehavior {
    Self.playbackBehavior(for: workbenchConfiguration)
  }

  @ViewBuilder
  private var playerContent: some View {
    if workbenchConfiguration != nil {
      workbenchPlayer
    } else {
      fullScreenPlayer
    }
  }

  private var fullScreenPlayer: some View {
    ZStack(alignment: .top) {
      VideoPlayer(player: player)
        .ignoresSafeArea()

      FeedbackVideoPlayerChrome(
        rateText: Self.rateText(rate),
        close: close,
        cycleRate: cycleRate
      )

      if markersFailed || markers?.isEmpty == false {
        FeedbackVideoMarkerOverlay(
          markers: markers ?? [],
          failed: markersFailed,
          currentSeconds: currentSeconds,
          durationSeconds: durationSeconds,
          seek: seek(toMilliseconds:)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
      }
    }
    .background(Color.black)
  }

  private var workbenchPlayer: some View {
    FeedbackVideoWorkbenchPlayer(
      player: player,
      rates: Self.rates,
      selectedRate: rate,
      isPlaying: isPlaying,
      currentSeconds: currentSeconds,
      durationSeconds: durationSeconds,
      markers: markers,
      togglePlayback: togglePlayback,
      selectRate: selectRate,
      addMarker: onAddMarker
    )
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
      switch playbackBehavior.retryCommand {
      case .none:
        break
      case .play:
        player.play()
      case .playImmediatelyAtSelectedRate:
        player.playImmediately(atRate: rate)
      }
      isPlaying = true
    }
  }

  private func cycleRate() {
    if playbackBehavior == .legacyFullScreen {
      let index = Self.rates.firstIndex(of: rate) ?? 1
      rate = Self.rates[(index + 1) % Self.rates.count]
      player.defaultRate = rate
      if player.timeControlStatus == .playing {
        player.rate = rate
      }
    } else {
      let index = Self.rates.firstIndex(of: rate) ?? 1
      selectRate(Self.rates[(index + 1) % Self.rates.count])
    }
  }

  private func selectRate(_ selectedRate: Float) {
    rate = selectedRate
    player.defaultRate = selectedRate
    if playbackBehavior.appliesSelectedRate(while: player.timeControlStatus) {
      player.rate = selectedRate
    }
  }

  private func togglePlayback() {
    if isPlaying {
      player.pause()
      isPlaying = false
    } else {
      if currentSeconds >= durationSeconds, durationSeconds > 0 {
        player.seek(to: .zero)
      }
      player.playImmediately(atRate: rate)
      isPlaying = true
    }
  }

  private func updateTimeline() {
    let current = player.currentTime().seconds
    if current.isFinite {
      currentSeconds = max(0, current)
      currentSecondsBinding?.wrappedValue = currentSeconds
    }
    let duration = player.currentItem?.duration.seconds ?? 0
    if duration.isFinite {
      durationSeconds = max(0, duration)
    }
  }

  private func seek(toMilliseconds milliseconds: Int) {
    let target = Self.seekTime(
      milliseconds: milliseconds,
      durationSeconds: durationSeconds
    )
    let tolerance = CMTime(value: 50, timescale: 1_000)
    player.seek(
      to: target,
      toleranceBefore: tolerance,
      toleranceAfter: tolerance
    )
    currentSeconds = max(0, target.seconds)
    currentSecondsBinding?.wrappedValue = currentSeconds
    onSeek(milliseconds)
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension FeedbackVideoPlayerView {
  static func rateText(_ rate: Float) -> String {
    switch rate {
    case 0.5: "0.5x"
    case 1.5: "1.5x"
    case 2: "2x"
    default: "1x"
    }
  }

  static func workbenchRateText(_ rate: Float) -> String {
    switch rate {
    case 0.5: "0.5×"
    case 1.5: "1.5×"
    case 2: "2×"
    default: "1×"
    }
  }

  public static func timeText(_ seconds: Double) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let remainder = totalSeconds % 60
    let secondText = remainder < 10 ? "0\(remainder)" : "\(remainder)"
    return "\(minutes):\(secondText)"
  }

  static func playbackBehavior(
    for configuration: FeedbackVideoWorkbenchConfiguration?
  ) -> FeedbackVideoPlaybackBehavior {
    configuration == nil ? .legacyFullScreen : .workbench
  }

  static func seekTime(milliseconds: Int, durationSeconds: Double) -> CMTime {
    let nonnegativeMilliseconds = max(0, milliseconds)
    let durationMilliseconds =
      durationSeconds.isFinite && durationSeconds > 0
      ? Int((durationSeconds * 1_000).rounded(.down))
      : nonnegativeMilliseconds
    return CMTime(
      value: CMTimeValue(min(nonnegativeMilliseconds, durationMilliseconds)),
      timescale: 1_000
    )
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
