import CoreModels
import DesignSystem
import SwiftUI

struct FeedbackVideoTimeline: View {
  let badge: VideoBadgeInfo?
  var showsAnnotation = false
  let markers: [VideoMarker]
  let markersFailed: Bool
  let seconds: Double
  let duration: Double
  let select: (VideoMarker) -> Void
  let update: (Double) -> Void
  let setScrubbing: (Bool) -> Void
  let refresh: (@MainActor () async -> Void)?

  @State private var refreshing = false
  @State private var selectedCueID: UUID?
  @State private var badgeExpanded = true

  var body: some View {
    GeometryReader { proxy in
      let scale = VideoBadgeLayout(size: proxy.size).scale
      VStack(alignment: .leading, spacing: 0) {
        Spacer(minLength: 0)
        if let badge, !showsAnnotation {
          VideoBadgeOverlay(info: badge, isExpanded: $badgeExpanded, scale: scale)
            .padding(.bottom, 14 * scale)
        }
        // Size the slot from the same font as the cue, including its insets.
        // The scrubber's 44pt hit area participates in the stack's layout.
        Text(ChatStrings.videoMarker)
          .font(.MeetPR.body(size: 20 * scale))
          .lineLimit(3, reservesSpace: true)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.vertical, 9 * scale)
          .hidden()
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityHidden(true)
          .overlay(alignment: .leading) { markerCue(scale: scale).padding(.leading, 44 * scale) }
          .padding(.bottom, 12 * scale)
        FeedbackVideoMarkerScrubber(
          markers: markers, seconds: seconds, duration: duration,
          scale: scale, select: selectMarker, update: update,
          setScrubbing: setScrubbing
        )
      }
      .padding(.bottom, max(0, 69 * scale - max(22, 12 * scale)))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
    .ignoresSafeArea(.container, edges: .bottom)
  }

  private func selectMarker(_ marker: VideoMarker) {
    selectedCueID = marker.id
    select(marker)
  }

  @ViewBuilder
  private func markerCue(scale: CGFloat) -> some View {
    let active = VideoMarkerWindow.active(in: markers, seconds: seconds)
    Group {
      if markersFailed {
        HStack {
          Text(ChatStrings.videoMarkersFailed)
          if let refresh {
            Button(ChatStrings.retry) {
              Task {
                refreshing = true
                defer { refreshing = false }
                await refresh()
              }
            }
            .disabled(refreshing)
          }
        }
        .font(.MeetPR.body(size: 20 * scale))
        .foregroundStyle(.white)
        .padding(9 * scale)
        .background(VideoBadgePalette.cardFill, in: .capsule)
      } else if let active {
        FeedbackVideoMarkerCue(
          marker: active, selected: selectedCueID == active.id, scale: scale, select: selectMarker
        )
        .id(active.id)
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: active?.id)
    .onChange(of: active?.id) { _, newID in
      if selectedCueID != newID { selectedCueID = nil }
    }
  }

}
