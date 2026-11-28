import CoreModels
import DesignSystem
import SwiftUI

/// Ticks, thumb, drag seeking and nearest-tick hit testing share one track.
struct FeedbackVideoMarkerScrubber: View {
  let markers: [VideoMarker]
  let seconds: Double
  let duration: Double
  let scale: CGFloat
  let select: (VideoMarker) -> Void
  let update: (Double) -> Void
  let setScrubbing: (Bool) -> Void
  @State private var dragging = false

  var body: some View {
    HStack(spacing: 14 * scale) {
      Text(FeedbackVideoPlayerView.timeText(seconds))
      GeometryReader { proxy in
        let radius = 12 * scale
        let width = max(1, proxy.size.width - 2 * radius)
        let progress = distance(at: seconds, width: width)
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.3)).frame(height: 6 * scale)
          Capsule().fill(VideoBadgePalette.amber).frame(width: progress, height: 6 * scale)
          ForEach(markers) { marker in
            RoundedRectangle(cornerRadius: 3 * scale)
              .fill(VideoBadgePalette.gold)
              .frame(width: 5 * scale, height: 22 * scale)
              .offset(x: markerX(marker, width: width) - 2.5 * scale)
          }
          Circle().fill(.white)
            .frame(width: 2 * radius, height: 2 * radius)
            .offset(x: progress - radius)
        }
        .frame(width: width, height: proxy.size.height, alignment: .leading)
        .padding(.horizontal, radius)
        .contentShape(.rect)
        .gesture(trackGesture(width: width, inset: radius))
        .accessibilityRepresentation {
          VStack {
            Slider(value: Binding(get: { seconds }, set: { seek($0) }), in: 0...max(1, duration))
              .accessibilityLabel(ChatStrings.playbackProgress)
              .accessibilityIdentifier("feedback.video.scrubber")
            ForEach(markers) { marker in
              Button(
                ChatStrings.seekToVideoMarker(
                  FeedbackVideoPlayerView.timeText(Double(marker.timeMilliseconds) / 1_000))
              ) {
                select(marker)
              }
              .accessibilityHint(marker.note)
            }
          }
        }
      }
      .frame(height: max(44, 24 * scale))
      .disabled(duration <= 0)
      Text(FeedbackVideoPlayerView.timeText(duration))
    }
    .font(.MeetPR.mono(size: 17 * scale))
    .foregroundStyle(.white)
    .monospacedDigit()
    .padding(.horizontal, 26 * scale)
  }

  private func distance(at time: Double, width: CGFloat) -> CGFloat {
    duration > 0 ? min(1, max(0, time / duration)) * width : 0
  }

  private func markerX(_ marker: VideoMarker, width: CGFloat) -> CGFloat {
    distance(at: Double(marker.timeMilliseconds) / 1_000, width: width)
  }

  private func seek(_ time: Double) {
    setScrubbing(true)
    update(time)
    setScrubbing(false)
  }

  private func trackGesture(width: CGFloat, inset: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        guard dragging || abs(value.translation.width) > 3 else { return }
        if !dragging {
          dragging = true
          setScrubbing(true)
        }
        update((value.location.x - inset) / width * duration)
      }
      .onEnded { value in
        let location = value.location.x - inset
        let time = min(duration, max(0, location / width * duration))
        if dragging {
          update(time)
          setScrubbing(false)
          dragging = false
        } else if let closest = markers.min(by: {
          abs(markerX($0, width: width) - location) < abs(markerX($1, width: width) - location)
        }), abs(markerX(closest, width: width) - location) <= 22 {
          select(closest)
        } else {
          seek(time)
        }
      }
  }
}
