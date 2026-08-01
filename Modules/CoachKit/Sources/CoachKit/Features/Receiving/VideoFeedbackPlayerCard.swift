import ChatUI
import CoreModels
import DesignSystem
import SwiftUI

@MainActor
struct VideoFeedbackPlayerCard: View {
  let itemID: UUID
  let playbackURL: URL?
  let isLoading: Bool
  let hasError: Bool
  @Binding var currentSeconds: Double
  @Binding var selectedAnnotationMarker: VideoMarker?
  let markers: [VideoMarker]?
  let refreshURL: @MainActor (UUID) async throws -> URL
  let retry: () -> Void
  let addMarker: (() -> Void)?
  let refreshMarkers: @MainActor () async -> Void

  var body: some View {
    if let playbackURL {
      FeedbackVideoPlayerView(
        videoID: itemID,
        url: playbackURL,
        workbenchConfiguration: FeedbackVideoWorkbenchConfiguration(),
        currentSeconds: $currentSeconds,
        markers: markers,
        selectedAnnotationMarker: $selectedAnnotationMarker,
        onAddMarker: addMarker,
        onMarkersRefresh: refreshMarkers,
        refreshURL: refreshURL
      )
      .id(itemID)
    } else {
      VStack {
        if isLoading {
          ProgressView()
            .tint(.white)
            .accessibilityLabel(CoachVideoFeedbackStrings.loading)
        } else if hasError {
          Button(action: retry) {
            VStack(spacing: MeetPRSpacing.space2) {
              Text(CoachVideoFeedbackStrings.playFailed)
              Text(CoachVideoFeedbackStrings.retry)
                .bold()
            }
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
            .foregroundStyle(.white)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("coach.video.retry")
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 270)
      .background(Color.MeetPR.videoStageFill)
      .clipShape(.rect(cornerRadius: MeetPRRadius.inset))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.inset)
          .stroke(Color.MeetPR.videoStageBorder, lineWidth: MeetPRSpacing.point1)
      }
      .padding(MeetPRSpacing.space3)
      .background(Color.MeetPR.textPrimary)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    }
  }
}
