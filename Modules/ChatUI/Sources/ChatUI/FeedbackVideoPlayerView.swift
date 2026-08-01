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
// The shared player intentionally owns the AVPlayer lifecycle and both presentation modes.
// swiftlint:disable:next type_body_length
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
  @State private var internalAnnotationMarker: VideoMarker?

  private let videoID: UUID
  private let refreshURL: @MainActor (UUID) async throws -> URL
  private let workbenchConfiguration: FeedbackVideoWorkbenchConfiguration?
  private let currentSecondsBinding: Binding<Double>?
  private let markers: [VideoMarker]?
  private let markersFailed: Bool
  private let selectedAnnotationMarker: Binding<VideoMarker?>?
  private let onSeek: @MainActor (Int) -> Void
  private let onAddMarker: (@MainActor () -> Void)?
  private let onMarkersRefresh: (@MainActor () async -> Void)?

  public init(
    videoID: UUID,
    url: URL,
    workbenchConfiguration: FeedbackVideoWorkbenchConfiguration? = nil,
    currentSeconds: Binding<Double>? = nil,
    markers: [VideoMarker]? = nil,
    markersFailed: Bool = false,
    selectedAnnotationMarker: Binding<VideoMarker?>? = nil,
    onSeek: @escaping @MainActor (Int) -> Void = { _ in },
    onAddMarker: (@MainActor () -> Void)? = nil,
    onMarkersRefresh: (@MainActor () async -> Void)? = nil,
    refreshURL: @escaping @MainActor (UUID) async throws -> URL
  ) {
    self.videoID = videoID
    self.refreshURL = refreshURL
    self.workbenchConfiguration = workbenchConfiguration
    currentSecondsBinding = currentSeconds
    self.markers = markers
    self.markersFailed = markersFailed
    self.selectedAnnotationMarker = selectedAnnotationMarker
    self.onSeek = onSeek
    self.onAddMarker = onAddMarker
    self.onMarkersRefresh = onMarkersRefresh
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
        if let annotationMarker {
          pauseAndSeek(to: annotationMarker)
        }
      }
      .onDisappear {
        player.pause()
      }
      .onChange(of: selectedAnnotationMarker?.wrappedValue) { oldMarker, newMarker in
        guard oldMarker?.id != newMarker?.id, let newMarker else { return }
        pauseAndSeek(to: newMarker)
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
          seek: seek(toMilliseconds:),
          selectMarker: selectMarker
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
      }

      if let annotationMarker, let annotationURL = annotationMarker.annotationURL {
        FeedbackVideoAnnotationOverlay(
          url: annotationURL,
          close: closeAnnotation,
          loadFailed: annotationLoadFailed
        )
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
      annotationMarker: annotationMarker,
      closeAnnotation: closeAnnotation,
      annotationLoadFailed: annotationLoadFailed,
      togglePlayback: togglePlayback,
      selectRate: selectRate,
      addMarker: onAddMarker
    )
  }

  private func close() {
    player.pause()
    dismiss()
  }

  private var annotationMarker: VideoMarker? {
    selectedAnnotationMarker?.wrappedValue ?? internalAnnotationMarker
  }

  private func selectMarker(_ marker: VideoMarker) {
    guard marker.annotationURL != nil else {
      seek(toMilliseconds: marker.timeMilliseconds)
      return
    }
    pauseAndSeek(to: marker)
    setAnnotationMarker(marker)
  }

  private func pauseAndSeek(to marker: VideoMarker) {
    player.pause()
    isPlaying = false
    seek(toMilliseconds: marker.timeMilliseconds)
  }

  private func closeAnnotation() {
    setAnnotationMarker(nil)
  }

  private func annotationLoadFailed() {
    closeAnnotation()
    guard let onMarkersRefresh else { return }
    Task {
      await onMarkersRefresh()
    }
  }

  private func setAnnotationMarker(_ marker: VideoMarker?) {
    if let selectedAnnotationMarker {
      selectedAnnotationMarker.wrappedValue = marker
    } else {
      internalAnnotationMarker = marker
    }
  }

  private func retry() {
    retrying = true
    Task {
      defer { retrying = false }
      guard let fresh = try? await refreshURL(videoID) else {
        return
      }
      playbackFailed = false
      // Replacing the item resumes playback: the annotation overlay's
      // paused-frame contract cannot hold across the swap, so close it.
      closeAnnotation()
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
