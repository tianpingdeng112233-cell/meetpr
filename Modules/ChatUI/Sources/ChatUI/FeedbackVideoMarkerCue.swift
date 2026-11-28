import CoreModels
import DesignSystem
import SwiftUI

struct FeedbackVideoMarkerCue: View {
  let marker: VideoMarker
  let selected: Bool
  let scale: CGFloat
  let select: (VideoMarker) -> Void

  var body: some View {
    Button {
      select(marker)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 12 * scale) {
        Text(FeedbackVideoPlayerView.timeText(Double(marker.timeMilliseconds) / 1_000))
          .font(.MeetPR.mono(size: 16 * scale))
          .foregroundStyle(VideoBadgePalette.gold)
          .fixedSize()
        let note = Text(marker.note.isEmpty ? ChatStrings.videoMarker : marker.note)
          .font(.MeetPR.body(size: 20 * scale))
          .foregroundStyle(.white)
          .lineLimit(selected ? nil : 3)
          .fixedSize(horizontal: false, vertical: true)
        if selected {
          ViewThatFits(in: .vertical) {
            note
            ScrollView { note.frame(maxWidth: .infinity, alignment: .leading) }
          }
        } else {
          note
        }
        if marker.annotationURL != nil {
          Image(systemName: "pencil")
            .font(.system(size: 16 * scale))
            .foregroundStyle(VideoBadgePalette.gold)
            .accessibilityHidden(true)
            .accessibilityIdentifier("feedback.video.marker.annotationBadge")
        }
      }
      .padding(.horizontal, 20 * scale)
      .padding(.vertical, 9 * scale)
      .background(VideoBadgePalette.cardFill, in: .rect(cornerRadius: 22 * scale))
    }
    .buttonStyle(.plain)
    .frame(maxWidth: 452 * scale, alignment: .leading)
  }
}
