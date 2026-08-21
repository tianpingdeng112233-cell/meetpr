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
  static let rates: [Float] = [0.5, 1.0, 1.5, 2.0]

  @Environment(\.dismiss) private var dismiss
  @State var player: AVPlayer
  @State var rate: Float = 1.0
  @State var playbackFailed = false
  @State var retrying = false
  @State var isPlaying = false
  @State var currentSeconds = 0.0
  @State var durationSeconds = 0.0
  @State private var internalAnnotationMarker: VideoMarker?
  @State private var badgeExpanded = true
  @State var playbackURL: URL
  @State var isExporting = false
  @State var showingCoachExportConfirmation = false
  @State var showingExportFailure = false
  @State var exportFailureMessage = ""
  @State var showingSavedToast = false
  @State var exportTask: Task<Void, Never>?
  @State var scrubState = FeedbackVideoScrubState()
  @State var scrubSeekTask: Task<Void, Never>?
  @State var pendingScrubSeconds: Double?
  @State var scrubGeneration = 0

  let videoID: UUID
  let refreshURL: @MainActor (UUID) async throws -> URL
  private let workbenchConfiguration: FeedbackVideoWorkbenchConfiguration?
  let badge: VideoBadgeInfo?
  let requiresCoachExportConfirmation: Bool
  let currentSecondsBinding: Binding<Double>?
  private let markers: [VideoMarker]?
  private let markersFailed: Bool
  private let selectedAnnotationMarker: Binding<VideoMarker?>?
  let onSeek: @MainActor (Int) -> Void
  private let onAddMarker: (@MainActor () -> Void)?
  private let onMarkersRefresh: (@MainActor () async -> Void)?

  public init(
    videoID: UUID,
    url: URL,
    workbenchConfiguration: FeedbackVideoWorkbenchConfiguration? = nil,
    currentSeconds: Binding<Double>? = nil,
    markers: [VideoMarker]? = nil,
    badge: VideoBadgeInfo? = nil,
    requiresCoachExportConfirmation: Bool = false,
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
    self.badge = badge
    self.requiresCoachExportConfirmation = requiresCoachExportConfirmation
    self.markersFailed = markersFailed
    self.selectedAnnotationMarker = selectedAnnotationMarker
    self.onSeek = onSeek
    self.onAddMarker = onAddMarker
    self.onMarkersRefresh = onMarkersRefresh
    _player = State(initialValue: AVPlayer(url: url))
    _playbackURL = State(initialValue: url)
  }

  public var body: some View {
    playerContent
      .overlay {
        if playbackFailed {
          FeedbackVideoFailureCard(retrying: retrying, retry: retry)
        }
      }
      .overlay(alignment: .top) {
        if showingSavedToast {
          Text(ChatStrings.videoExportSaved)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.horizontal, MeetPRSpacing.space4)
            .padding(.vertical, MeetPRSpacing.point10)
            .background(Color.MeetPR.bgInset.opacity(0.96), in: .capsule)
            .overlay {
              Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
            .padding(.top, MeetPRSpacing.point56)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityIdentifier("feedback.video.exportSaved")
        }
      }
      .alert(
        ChatStrings.coachExportConfirmationTitle,
        isPresented: $showingCoachExportConfirmation
      ) {
        Button(ChatStrings.cancel, role: .cancel) {}
        Button(ChatStrings.coachExportConfirmationAction) {
          UserDefaults.standard.set(
            true,
            forKey: Self.coachExportConfirmationDefaultsKey
          )
          startExport()
        }
      } message: {
        Text(ChatStrings.coachExportConfirmationMessage)
      }
      .alert(ChatStrings.videoExportFailed, isPresented: $showingExportFailure) {
        Button(ChatStrings.close, role: .cancel) {}
      } message: {
        Text(exportFailureMessage)
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
        scrubSeekTask?.cancel()
        exportTask?.cancel()
        player.pause()
      }
      .onChange(of: selectedAnnotationMarker?.wrappedValue) { oldMarker, newMarker in
        guard oldMarker?.id != newMarker?.id, let newMarker else { return }
        pauseAndSeek(to: newMarker)
      }
      .task {
        while !Task.isCancelled {
          updateTimeline()
          try? await Task.sleep(for: .milliseconds(250))
        }
      }
  }

  var playbackBehavior: FeedbackVideoPlaybackBehavior {
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
        isExporting: isExporting,
        close: close,
        cycleRate: cycleRate,
        export: exportAction
      )

      VStack(spacing: 0) {
        // The badge region is greedy (GeometryReader) and bottom-aligned, so
        // the card always sits directly above whatever the markers panel and
        // scrubber actually measure — no hard-coded inset to drift out of sync.
        if let badge {
          VideoBadgeOverlay(info: badge, isExpanded: $badgeExpanded)
            .padding(.bottom, MeetPRSpacing.point13)
        } else {
          Spacer()
        }

        if markersFailed || markers?.isEmpty == false {
          FeedbackVideoMarkerOverlay(
            markers: markers ?? [],
            failed: markersFailed,
            currentSeconds: currentSeconds,
            durationSeconds: durationSeconds,
            seek: seek(toMilliseconds:),
            selectMarker: selectMarker
          )
        }

        FeedbackVideoScrubber(
          positionSeconds: scrubberPositionSeconds,
          durationSeconds: durationSeconds,
          layout: .fullScreen,
          updatePosition: updateScrubberPosition,
          setScrubbing: setScrubbing
        )
      }

      if let annotationMarker, let annotationURL = annotationMarker.annotationURL {
        FeedbackVideoAnnotationOverlay(
          url: annotationURL,
          close: closeAnnotation,
          loadFailed: annotationLoadFailed
        )
      }

    }
    .background(SwiftUI.Color.black)
  }

  private var workbenchPlayer: some View {
    FeedbackVideoWorkbenchPlayer(
      player: player,
      rates: Self.rates,
      selectedRate: rate,
      isPlaying: isPlaying,
      scrubberPositionSeconds: scrubberPositionSeconds,
      durationSeconds: durationSeconds,
      annotationMarker: annotationMarker,
      closeAnnotation: closeAnnotation,
      annotationLoadFailed: annotationLoadFailed,
      togglePlayback: togglePlayback,
      selectRate: selectRate,
      updateScrubberPosition: updateScrubberPosition,
      setScrubbing: setScrubbing,
      addMarker: onAddMarker,
      badge: badge,
      badgeExpanded: $badgeExpanded,
      isExporting: isExporting,
      export: exportAction
    )
  }

  private var exportAction: (() -> Void)? {
    guard badge != nil else { return nil }
    return { requestExport() }
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

  func closeAnnotation() {
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
