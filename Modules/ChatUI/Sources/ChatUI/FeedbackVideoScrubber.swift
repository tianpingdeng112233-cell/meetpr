import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoScrubber: View {
  enum Layout {
    case fullScreen
    case workbench
  }

  let positionSeconds: Double
  let durationSeconds: Double
  let layout: Layout
  let updatePosition: (Double) -> Void
  let setScrubbing: (Bool) -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      timelineText(FeedbackVideoPlayerView.timeText(positionSeconds))

      Slider(
        value: Binding(
          get: { min(max(positionSeconds, 0), sliderUpperBound) },
          set: { newValue in updatePosition(newValue) }
        ),
        in: 0...sliderUpperBound,
        onEditingChanged: { isScrubbing in setScrubbing(isScrubbing) }
      )
      .tint(Color.MeetPR.gold500)
      .disabled(durationSeconds <= 0)
      .accessibilityLabel(ChatStrings.playbackProgress)
      .accessibilityValue(
        "\(FeedbackVideoPlayerView.timeText(positionSeconds)) / "
          + FeedbackVideoPlayerView.timeText(durationSeconds)
      )
      .accessibilityIdentifier("feedback.video.scrubber")

      timelineText(FeedbackVideoPlayerView.timeText(durationSeconds))
    }
    .padding(.horizontal, layout == .fullScreen ? MeetPRSpacing.base : 0)
    .padding(.vertical, layout == .fullScreen ? MeetPRSpacing.sm : 0)
    .background {
      if layout == .fullScreen {
        Rectangle().fill(.ultraThinMaterial)
      }
    }
  }

  private var sliderUpperBound: Double {
    max(durationSeconds, 1)
  }

  private func timelineText(_ text: String) -> some View {
    Text(text)
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
      .foregroundStyle(timelineColor)
      .monospacedDigit()
  }

  private var timelineColor: Color {
    layout == .fullScreen ? .white.opacity(0.82) : Color.MeetPR.textDisabled
  }
}
