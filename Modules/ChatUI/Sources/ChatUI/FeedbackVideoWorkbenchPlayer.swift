import AVKit
import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoWorkbenchPlayer: View {
  let player: AVPlayer
  let rates: [Float]
  let selectedRate: Float
  let isPlaying: Bool
  let currentSeconds: Double
  let durationSeconds: Double
  let markers: [VideoMarker]?
  let togglePlayback: () -> Void
  let selectRate: (Float) -> Void
  let addMarker: (() -> Void)?

  var body: some View {
    VStack(spacing: MeetPRSpacing.point11) {
      playbackStage

      HStack(spacing: MeetPRSpacing.point10) {
        timelineText(FeedbackVideoPlayerView.timeText(currentSeconds))
        progressTrack
        timelineText(FeedbackVideoPlayerView.timeText(durationSeconds))
      }

      HStack(spacing: MeetPRSpacing.space2) {
        ratePicker
        if let addMarker {
          Button(action: addMarker) {
            Text(ChatStrings.addVideoMarker)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, MeetPRSpacing.space3)
              .padding(.vertical, MeetPRSpacing.point7)
              .overlay {
                RoundedRectangle(cornerRadius: MeetPRRadius.inset)
                  .stroke(Color.MeetPR.videoStageBorder, lineWidth: MeetPRSpacing.point1)
              }
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("feedback.video.addMarker")
        }
      }
    }
    .padding(MeetPRSpacing.space3)
    .background(Color.MeetPR.textPrimary)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .accessibilityValue(
      "\(ChatStrings.playbackSpeed) \(FeedbackVideoPlayerView.workbenchRateText(selectedRate))"
    )
  }

  private var playbackStage: some View {
    ZStack {
      VideoPlayer(player: player)
        .allowsHitTesting(false)

      Button(action: togglePlayback) {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
          .font(
            .MeetPR.system(
              size: isPlaying ? MeetPRFontMetrics.size20 : MeetPRFontMetrics.size22,
              weight: .bold
            )
          )
          .foregroundStyle(.white)
          .frame(width: MeetPRSpacing.point56, height: MeetPRSpacing.point56)
          .background(.white.opacity(0.14), in: .circle)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isPlaying ? ChatStrings.pausePlayback : ChatStrings.playPlayback)
      .accessibilityIdentifier("feedback.video.playbackToggle")
    }
    .frame(height: 270)
    .background(Color.MeetPR.videoStageFill)
    .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.inset)
        .stroke(Color.MeetPR.videoStageBorder, lineWidth: MeetPRSpacing.point1)
    }
  }

  private var ratePicker: some View {
    HStack(spacing: 0) {
      ForEach(rates, id: \.self) { option in
        Button {
          selectRate(option)
        } label: {
          Text(FeedbackVideoPlayerView.workbenchRateText(option))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .foregroundStyle(option == selectedRate ? Color.white : Color.MeetPR.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeetPRSpacing.point6)
            .background(
              option == selectedRate ? Color.MeetPR.textPrimary : Color.clear,
              in: .rect(cornerRadius: MeetPRSpacing.point7)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          "\(ChatStrings.playbackSpeed) \(FeedbackVideoPlayerView.workbenchRateText(option))"
        )
        .accessibilityValue(option == selectedRate ? ChatStrings.selected : "")
        .accessibilityIdentifier(
          "feedback.video.speed.\(FeedbackVideoPlayerView.rateText(option))"
        )
      }
    }
    .padding(MeetPRSpacing.point3)
    .background(.white.opacity(0.08))
    .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
  }

  private var progressTrack: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.MeetPR.videoStageBorder)
        Capsule()
          .fill(Color.white)
          .frame(width: proxy.size.width * progressFraction)
        ForEach(markers ?? []) { marker in
          RoundedRectangle(cornerRadius: MeetPRSpacing.point2)
            .fill(Color.MeetPR.gold500)
            .frame(width: MeetPRSpacing.point3, height: MeetPRSpacing.point10)
            .offset(x: markerOffset(marker, trackWidth: proxy.size.width))
        }
      }
    }
    .frame(height: MeetPRSpacing.space1)
    .accessibilityLabel(ChatStrings.playbackProgress)
    .accessibilityValue(
      "\(FeedbackVideoPlayerView.timeText(currentSeconds)) / "
        + FeedbackVideoPlayerView.timeText(durationSeconds)
    )
    .accessibilityIdentifier("feedback.video.progress")
  }

  private func timelineText(_ text: String) -> some View {
    Text(text)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
      .foregroundStyle(Color.MeetPR.textDisabled)
      .monospacedDigit()
  }

  private var progressFraction: CGFloat {
    guard durationSeconds > 0 else { return 0 }
    return CGFloat(min(max(currentSeconds / durationSeconds, 0), 1))
  }

  private func markerOffset(_ marker: VideoMarker, trackWidth: CGFloat) -> CGFloat {
    guard durationSeconds > 0 else { return 0 }
    let seconds = Double(marker.timeMilliseconds) / 1_000
    let fraction = min(max(seconds / durationSeconds, 0), 1)
    return max(0, trackWidth * fraction - MeetPRSpacing.point1)
  }
}
