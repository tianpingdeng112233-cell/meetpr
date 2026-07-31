import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoMarkerOverlay: View {
  let markers: [VideoMarker]
  /// The endpoint answered with a non-404 error: keep the surface visible
  /// with a failure line instead of silently hiding the coach's markers.
  var failed = false
  let currentSeconds: Double
  let durationSeconds: Double
  let seek: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      HStack {
        Text(
          failed
            ? ChatStrings.videoMarkersFailed
            : ChatStrings.videoMarkers(markers.count)
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .semibold))
        Spacer()
        Text(
          "\(FeedbackVideoPlayerView.timeText(currentSeconds)) / "
            + FeedbackVideoPlayerView.timeText(durationSeconds)
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .monospacedDigit()
      }
      .foregroundStyle(.white.opacity(0.82))

      ScrollView {
        VStack(spacing: 0) {
          ForEach(markers) { marker in
            Button {
              seek(marker.timeMilliseconds)
            } label: {
              HStack(spacing: MeetPRSpacing.sm) {
                Text(FeedbackVideoPlayerView.timeText(Double(marker.timeMilliseconds) / 1_000))
                  .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
                  .foregroundStyle(Color.MeetPR.gold500)
                Text(marker.note.isEmpty ? ChatStrings.videoMarker : marker.note)
                  .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
                  .foregroundStyle(.white)
                  .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "forward.fill")
                  .font(.system(size: MeetPRFontMetrics.size11))
                  .foregroundStyle(.white.opacity(0.72))
              }
              .padding(.vertical, MeetPRSpacing.sm)
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
              ChatStrings.seekToVideoMarker(
                FeedbackVideoPlayerView.timeText(Double(marker.timeMilliseconds) / 1_000)
              )
            )
          }
        }
      }
      .frame(maxHeight: 190)
      .scrollIndicators(.hidden)
    }
    .padding(MeetPRSpacing.base)
    .background(.black.opacity(0.72))
  }
}
