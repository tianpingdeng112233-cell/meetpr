#if os(iOS)
  import AVFoundation
  import DesignSystem
  import SwiftUI
  import UIKit

  struct VideoTrimView: View {
    let session: VideoTrimSession

    @State private var player = AVPlayer()
    @State private var selection: VideoTrimSelection
    @State private var thumbnails: [VideoTrimThumbnail] = []
    @State private var isReady = false
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var exportTask: Task<Void, Never>?

    init(session: VideoTrimSession) {
      self.session = session
      _selection = State(
        initialValue: VideoTrimSelection(
          sourceDurationSeconds: 0,
          maxDurationSeconds: session.maxDurationSeconds
        )
      )
    }

    var body: some View {
      // The background ignores the safe area as a `.background` rather than a
      // ZStack sibling: inside a ZStack it would widen the stack's frame and
      // drag the toolbar up under the status bar with it (the #315 trap).
      VStack(spacing: 0) {
        VideoTrimToolbar(
          canSave: isReady && selection.isValid && !isExporting,
          canCancel: !isExporting,
          isExporting: isExporting,
          onCancel: cancel,
          onSave: save
        )
        VideoTrimTimeline(
          selection: selection,
          thumbnails: thumbnails,
          onMoveStart: moveStart,
          onMoveEnd: moveEnd
        )
        .padding(.horizontal, MeetPRSpacing.space4)
        .padding(.vertical, MeetPRSpacing.space3)
        .background(Color.MeetPR.surfaceCard)

        VideoTrimPlayerSurface(player: player)
          .overlay {
            if !isReady {
              ProgressView(StudentStrings.localized(.videoTrimView001))
                .tint(.white)
                .foregroundStyle(.white)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black)

        VideoTrimPlaybackControls(
          isPlaying: isPlaying, isEnabled: isReady, action: togglePlayback)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bgBase.ignoresSafeArea())
      .modifier(TopSafeAreaFallback())
      .interactiveDismissDisabled(isExporting)
      .task(id: session.id) { await prepare() }
      .onDisappear {
        playbackTask?.cancel()
        // The export holds the source file; cancelling lets its cancellation
        // handler tear the session down instead of writing into a dead cover.
        exportTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
      }
    }

    private func prepare() async {
      do {
        let asset = AVURLAsset(url: session.sourceURL)
        let duration = try await asset.load(.duration)
        // The exporter downstream requires exactly one video track, so an
        // asset that can never survive upload must fail here rather than
        // reach a savable state and strand a permanently-failed record.
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        // Every write below — terminal outcome, player item, ready flag — must
        // be gated on cancellation: `.task(id:)` tears down on disappear and a
        // late write would target a cover that is already gone.
        try Task.checkCancellation()
        guard duration.isNumeric, duration.seconds > 0, videoTracks.count == 1 else {
          session.failed()
          return
        }
        selection = VideoTrimSelection(
          sourceDurationSeconds: duration.seconds,
          maxDurationSeconds: session.maxDurationSeconds
        )
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        isReady = true
        let generated = await VideoTrimThumbnailGenerator().thumbnails(
          sourceURL: session.sourceURL,
          durationSeconds: duration.seconds,
          count: 10
        )
        try Task.checkCancellation()
        thumbnails = generated
      } catch is CancellationError {
        // `.task(id:)` cancels on disappear; the cover's onDismiss owns the
        // outcome then. Reporting a failure here would turn a user cancel into
        // a spurious 「视频处理失败」.
      } catch {
        guard !Task.isCancelled else { return }
        session.failed()
      }
    }

    private func moveStart(_ seconds: Double) {
      pausePlayback()
      selection.moveStart(to: seconds)
      seek(to: selection.startSeconds)
    }

    private func moveEnd(_ seconds: Double) {
      pausePlayback()
      selection.moveEnd(to: seconds)
      seek(to: selection.endSeconds)
    }

    private func togglePlayback() {
      if isPlaying {
        pausePlayback()
        return
      }
      let currentSeconds = player.currentTime().seconds
      if !currentSeconds.isFinite
        || currentSeconds < selection.startSeconds
        || currentSeconds >= selection.endSeconds
      {
        seek(to: selection.startSeconds)
      }
      player.play()
      isPlaying = true
      playbackTask?.cancel()
      playbackTask = Task { @MainActor in
        while !Task.isCancelled, isPlaying {
          if player.currentTime().seconds >= selection.endSeconds - 0.03 {
            pausePlayback()
            seek(to: selection.startSeconds)
            return
          }
          try? await Task.sleep(for: .milliseconds(50))
        }
      }
    }

    private func pausePlayback() {
      playbackTask?.cancel()
      playbackTask = nil
      player.pause()
      isPlaying = false
    }

    private func seek(to seconds: Double) {
      player.seek(
        to: CMTime(seconds: seconds, preferredTimescale: 600),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      )
    }

    private func cancel() {
      guard !isExporting else { return }
      pausePlayback()
      session.cancelled()
    }

    private func save() {
      guard isReady, selection.isValid, !isExporting else { return }
      pausePlayback()
      isExporting = true
      let selection = selection
      exportTask = Task { @MainActor in
        await session.exportTrim(selection: selection)
        isExporting = false
      }
    }
  }

  /// A cover presented from inside another cover can arrive with its safe-area
  /// insets already zeroed, which puts the toolbar under the clock and battery
  /// (the same symptom #315 fixed for the recorder). Measure what SwiftUI hands
  /// us and, only when it is empty, fall back to the window's real inset — the
  /// recorder path already gets a correct inset and must not be padded twice.
  private struct TopSafeAreaFallback: ViewModifier {
    @State private var providedTopInset: CGFloat?

    func body(content: Content) -> some View {
      content
        .safeAreaInset(edge: .top, spacing: 0) {
          Color.clear.frame(height: fallbackTopInset)
        }
        .overlay {
          GeometryReader { proxy in
            Color.clear
              .onAppear { providedTopInset = proxy.safeAreaInsets.top }
          }
          .allowsHitTesting(false)
        }
    }

    private var fallbackTopInset: CGFloat {
      guard let providedTopInset, providedTopInset < 1 else { return 0 }
      return Self.windowTopInset
    }

    private static var windowTopInset: CGFloat {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .keyWindow?
        .safeAreaInsets.top ?? 0
    }
  }

  private struct VideoTrimToolbar: View {
    let canSave: Bool
    let canCancel: Bool
    let isExporting: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
      HStack {
        Button(action: onCancel) {
          Image(systemName: "xmark")
            .font(.system(size: MeetPRFontMetrics.size17, weight: .semibold))
            .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
        }
        .disabled(!canCancel)
        Spacer()
        Text(StudentStrings.localized(.videoTrimView002))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        Button(action: onSave) {
          if isExporting {
            ProgressView()
              .tint(Color.MeetPR.gold500)
              .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
          } else {
            Text(StudentStrings.localized(.videoTrimView003))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
              .frame(
                minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
          }
        }
        .foregroundStyle(Color.MeetPR.gold500)
        .disabled(!canSave)
      }
      .padding(.horizontal, MeetPRSpacing.space2)
      .background(Color.MeetPR.surfaceCard)
    }
  }

  private struct VideoTrimPlaybackControls: View {
    let isPlaying: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        Label(
          isPlaying
            ? StudentStrings.localized(.videoTrimView004)
            : StudentStrings.localized(.videoTrimView005),
          systemImage: isPlaying ? "pause.fill" : "play.fill"
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.gold500)
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.point56)
      }
      .disabled(!isEnabled)
      .background(Color.MeetPR.surfaceCard)
    }
  }

  private struct VideoTrimPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> VideoTrimPlayerUIView {
      let view = VideoTrimPlayerUIView()
      view.playerLayer.player = player
      return view
    }

    func updateUIView(_ uiView: VideoTrimPlayerUIView, context: Context) {
      uiView.playerLayer.player = player
    }
  }

  private final class VideoTrimPlayerUIView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
      guard let playerLayer = layer as? AVPlayerLayer else {
        preconditionFailure("VideoTrimPlayerUIView must use AVPlayerLayer")
      }
      playerLayer.videoGravity = .resizeAspect
      return playerLayer
    }
  }
#endif
