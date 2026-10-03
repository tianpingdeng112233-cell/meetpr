import AVFoundation
import ChatUI
import DesignSystem
import SwiftUI

@MainActor
struct SetEntryVideoPlayerView: View {
  let playback: SetEntryVideoPlayer
  let badge: VideoBadgeInfo?
  var isInline = false
  let retry: () -> Void

  var body: some View {
    Group {
      if playback.state.isExpanded && !isInline {
        SetEntryVideoStage(playback: playback, role: .expanded)
          .ignoresSafeArea()
          .overlay(alignment: .top) {
            SetEntryVideoHeader(badge: badge, collapse: { playback.state.handleBack() })
          }
          .overlay(alignment: .bottom) {
            SetEntryVideoControlBar(playback: playback, retry: retry)
          }
      } else {
        VStack(spacing: 0) {
          SetEntryVideoStage(
            playback: playback, role: .inline, isActive: !playback.state.isExpanded
          )
          .aspectRatio(16 / 9, contentMode: .fit)
          SetEntryVideoControlBar(playback: playback, retry: retry)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.card))
      }
    }
    .accessibilityAction(.escape) { playback.state.handleBack() }
    #if os(macOS)
      .onExitCommand { playback.state.handleBack() }
    #endif
  }
}

private struct SetEntryVideoStage: View {
  let playback: SetEntryVideoPlayer
  let role: SetEntryVideoPlayer.SurfaceRole
  var isActive = true

  var body: some View {
    ZStack {
      Color.black
      if playback.player != nil {
        if isActive { SetEntryVideoSurface(playback: playback, role: role) }
      } else {
        ProgressView().tint(.white)
      }
    }
  }
}

private struct SetEntryVideoControlBar: View {
  let playback: SetEntryVideoPlayer
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      if playback.hasError {
        Button(StudentStrings.localized(.videoAttachmentSection002), action: retry)
          .font(.MeetPR.footnote)
      }
      SetEntryVideoControls(playback: playback)
    }
    .foregroundStyle(.white)
    .background(.black.opacity(0.75))
  }
}

private struct SetEntryVideoControls: View {
  let playback: SetEntryVideoPlayer
  @State private var showsSpeeds = false

  var body: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.xs) {
      Button(action: playback.togglePlayback) {
        Image(systemName: playback.state.isPlaying ? "pause.fill" : "play.fill")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
      }
      .accessibilityLabel(
        StudentStrings.localized(
          playback.state.isPlaying ? .setEntryVideoPause : .setEntryVideoPlay))
      VStack(spacing: 0) {
        SetEntryVideoProgress(playback: playback)
        HStack {
          Text(duration(playback.state.position))
          Spacer(minLength: 0)
          Text(duration(playback.state.duration))
        }
        .font(.MeetPR.monoLabel)
      }
      Button {
        showsSpeeds.toggle()
      } label: {
        Text(playback.state.speed.label)
          .font(.MeetPR.footnote)
          .frame(
            minWidth: MeetPRSpacing.minimumHitTarget, minHeight: MeetPRSpacing.minimumHitTarget)
      }
      .accessibilityLabel(StudentStrings.localized(.setEntryVideoSpeed))
      .popover(isPresented: $showsSpeeds, arrowEdge: .bottom) {
        VStack(spacing: 0) {
          ForEach(SetEntryVideoPlaybackState.Speed.allCases, id: \.self) { speed in
            Button {
              playback.setSpeed(speed)
              showsSpeeds = false
            } label: {
              Text(speed.label)
                .font(.MeetPR.footnote)
                .frame(minWidth: MeetPRSpacing.point64, minHeight: MeetPRSpacing.minimumHitTarget)
                .background(speed == playback.state.speed ? Color.MeetPR.goldCTA : .clear)
            }
            .accessibilityAddTraits(speed == playback.state.speed ? .isSelected : [])
          }
        }
        .background(Color.MeetPR.videoStageFill, in: .rect(cornerRadius: MeetPRRadius.md))
        .presentationCompactAdaptation(.popover)
      }
      Button {
        showsSpeeds = false
        playback.state.toggleExpanded()
      } label: {
        Image(
          systemName: playback.state.isExpanded
            ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        )
        .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
      }
      .accessibilityLabel(
        StudentStrings.localized(
          playback.state.isExpanded ? .setEntryVideoCollapse : .setEntryVideoExpand))
    }
    .buttonStyle(.plain)
    .tint(.white)
    .padding(MeetPRSpacing.sm)
  }

  private func duration(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }
}

private struct SetEntryVideoHeader: View {
  let badge: VideoBadgeInfo?
  let collapse: () -> Void

  private static func details(_ badge: VideoBadgeInfo) -> String {
    var parts: [String] = []
    if let number = badge.setOrdinal {
      parts.append(StudentStrings.replacing(.setEntryVideoSet, values: [String(number)]))
    }
    let weight = badge.weightKg.flatMap { $0.isFinite ? metric($0) + "kg" : nil }
    let reps = badge.reps.map { String($0) }
    let load = [weight, reps].compactMap { $0 }.joined(separator: " × ")
    if !load.isEmpty { parts.append(load) }
    if let rpe = badge.rpe, rpe.isFinite { parts.append("RPE " + metric(rpe)) }
    return parts.joined(separator: " · ")
  }

  private static func metric(_ value: Double) -> String {
    value.formatted(
      .number.grouping(.never).precision(.fractionLength(0...1))
        .locale(Locale(identifier: "en_US_POSIX")))
  }

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Button(action: collapse) {
        Image(systemName: "chevron.down")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
      }
      .accessibilityLabel(StudentStrings.localized(.setEntryVideoCollapse))
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        if let name = badge?.exerciseName { Text(name).font(.MeetPR.bodyEmphasis) }
        if let badge {
          Text(Self.details(badge))
            .font(.MeetPR.footnote)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(MeetPRSpacing.sm)
    .foregroundStyle(.white)
    .background(.black.opacity(0.65))
    .contentShape(.rect)
    .gesture(
      DragGesture().onEnded { value in
        if value.translation.height > MeetPRSpacing.minimumHitTarget { collapse() }
      })
  }
}

#if os(iOS)
  private struct SetEntryVideoSurface: UIViewRepresentable {
    let playback: SetEntryVideoPlayer
    let role: SetEntryVideoPlayer.SurfaceRole

    func makeUIView(context: Context) -> SetEntryVideoLayerView { SetEntryVideoLayerView() }
    func updateUIView(_ view: SetEntryVideoLayerView, context: Context) {
      view.attach(playback, role: role)
    }

    static func dismantleUIView(_ view: SetEntryVideoLayerView, coordinator: ()) {
      view.detach()
    }
  }

  private final class SetEntryVideoLayerView: UIView {
    private let videoLayer = AVPlayerLayer()
    private weak var playback: SetEntryVideoPlayer?
    private var role: SetEntryVideoPlayer.SurfaceRole = .inline

    func attach(_ playback: SetEntryVideoPlayer, role: SetEntryVideoPlayer.SurfaceRole) {
      self.playback = playback
      self.role = role
      if videoLayer.superlayer == nil { layer.addSublayer(videoLayer) }
      playback.attach(to: videoLayer, role: role)
      setNeedsLayout()
    }

    func detach() {
      playback?.detach(from: videoLayer, role: role)
      playback = nil
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      guard videoLayer.superlayer === layer else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      videoLayer.frame = bounds
      CATransaction.commit()
    }
  }
#elseif os(macOS)
  private struct SetEntryVideoSurface: NSViewRepresentable {
    let playback: SetEntryVideoPlayer
    let role: SetEntryVideoPlayer.SurfaceRole

    func makeNSView(context: Context) -> SetEntryVideoLayerView { SetEntryVideoLayerView() }
    func updateNSView(_ view: SetEntryVideoLayerView, context: Context) {
      view.attach(playback, role: role)
    }

    static func dismantleNSView(_ view: SetEntryVideoLayerView, coordinator: ()) {
      view.detach()
    }
  }

  private final class SetEntryVideoLayerView: NSView {
    private let videoLayer = AVPlayerLayer()
    private weak var playback: SetEntryVideoPlayer?
    private var role: SetEntryVideoPlayer.SurfaceRole = .inline

    func attach(_ playback: SetEntryVideoPlayer, role: SetEntryVideoPlayer.SurfaceRole) {
      wantsLayer = true
      self.playback = playback
      self.role = role
      if videoLayer.superlayer == nil { layer?.addSublayer(videoLayer) }
      playback.attach(to: videoLayer, role: role)
      needsLayout = true
    }

    func detach() {
      playback?.detach(from: videoLayer, role: role)
      playback = nil
    }

    override func layout() {
      super.layout()
      guard videoLayer.superlayer === layer else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      videoLayer.frame = bounds
      CATransaction.commit()
    }
  }
#endif
