import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct VideoMarkerRowLabel: View {
  let marker: VideoMarker

  var body: some View {
    HStack(spacing: MeetPRSpacing.point11) {
      Text(FeedbackVideoPlayerView.timeText(Double(marker.timeMilliseconds) / 1_000))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
        .foregroundStyle(Color.MeetPR.gold500)
      Text(marker.note.isEmpty ? CoachVideoFeedbackStrings.marker : marker.note)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
      if marker.annotationURL != nil {
        Image(systemName: "pencil")
          .font(.system(size: MeetPRFontMetrics.size11, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
          .accessibilityHidden(true)
          .accessibilityIdentifier("coach.video.marker.annotationBadge")
      }
    }
  }
}
