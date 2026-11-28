import AVFoundation
import ChatUI
import DesignSystem
import SwiftUI

@MainActor
struct SetEntryVideoPlayerView: View {
  let playback: SetEntryVideoPlayer
  let badge: VideoBadgeInfo?
  var isInline = false
  var readOnly = false
  var showsPlaybackError = true
  var onClose: (() -> Void)?
  var onReview: (() -> Void)?
  let retry: () -> Void
  @State private var albumExport = VideoBadgeAlbumExport()
  @State private var badgeExpanded = true
  @State private var size = CGSize.zero

  var body: some View {
    Group {
      if readOnly || (playback.state.isExpanded && !isInline) {
        SetEntryVideoStage(playback: playback, role: .expanded)
          .ignoresSafeArea()
          .overlay(alignment: .top) {
            if readOnly {
              CompletedVideoPlayerHeader(
                close: { onClose?() }, onReview: onReview, saveButton: saveButton)
            } else {
              SetEntryVideoHeader(saveButton: saveButton, collapse: { playback.state.handleBack() })
            }
          }
          .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              if let badge, badge.hasContent {
                VideoBadgeOverlay(info: badge, isExpanded: $badgeExpanded, size: size)
                  .padding(.bottom, min(size.width, size.height * 9 / 16) * 52 / 540)
              }
              SetEntryVideoControlBar(
                playback: playback, allowsExpansion: !readOnly, showsError: showsPlaybackError,
                retry: retry)
            }
          }
          .onGeometryChange(for: CGSize.self) {
            $0.size
          } action: {
            size = $0
          }
          .modifier(VideoBadgeExportFeedback(job: albumExport))
          .onAppear { badgeExpanded = true }
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
    .accessibilityAction(.escape) {
      if readOnly { onClose?() } else { playback.state.handleBack() }
    }
    #if os(macOS)
      .onExitCommand {
        if readOnly { onClose?() } else { playback.state.handleBack() }
      }
    #endif
  }
  private var saveButton: VideoBadgeSaveButton? {
    guard let badge, badge.hasContent,
      let asset = playback.player?.currentItem?.asset as? AVURLAsset
    else { return nil }
    return VideoBadgeSaveButton(isExporting: albumExport.isExporting) {
      albumExport.start(sourceURL: asset.url, badge: badge)
    }
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
      if isActive, playback.player != nil, !playback.state.isPlaying {
        Button(action: playback.togglePlayback) {
          Image(systemName: "play.fill")
            .font(.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.inkOnCTAFill)
            .frame(width: MeetPRSpacing.point56, height: MeetPRSpacing.point56)
            .background(Color.MeetPR.ctaFill.opacity(0.65), in: .circle)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StudentStrings.localized(.setEntryVideoPlay))
        .accessibilityIdentifier("setEntryVideo.centralPlay")
      }
    }
  }
}

private struct SetEntryVideoControlBar: View {
  let playback: SetEntryVideoPlayer
  var allowsExpansion = true
  var showsError = true
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.xs) {
      if playback.hasError && showsError {
        Button(StudentStrings.localized(.videoAttachmentSection002), action: retry)
          .font(.MeetPR.footnote)
      }
      SetEntryVideoControls(playback: playback, allowsExpansion: allowsExpansion)
    }
    .foregroundStyle(.white)
    .background(.black.opacity(0.75))
  }
}

private struct SetEntryVideoControls: View {
  let playback: SetEntryVideoPlayer
  let allowsExpansion: Bool
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
      if allowsExpansion {
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
  let saveButton: VideoBadgeSaveButton?
  let collapse: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Button(action: collapse) {
        Image(systemName: "chevron.down")
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
      }
      .accessibilityLabel(StudentStrings.localized(.setEntryVideoCollapse))
      Spacer(minLength: 0)
      saveButton
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
