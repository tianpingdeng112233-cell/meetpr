import CoreModels
import DesignSystem
import SwiftUI

public struct ChatStandaloneVideoCard: View {
  private let message: ChatMessage
  private let openVideo: @MainActor () -> Void

  public init(message: ChatMessage, openVideo: @escaping @MainActor () -> Void) {
    self.message = message
    self.openVideo = openVideo
  }

  public var body: some View {
    Button(action: openVideo) {
      ZStack {
        Color.MeetPR.surfaceRaised
        ChatVideoPoster(url: message.posterURL, videoID: message.videoID)
        Image(systemName: "play.fill")
          .font(.title2)
          .foregroundStyle(.white)
          .padding(MeetPRSpacing.md)
          .background(.black.opacity(0.45), in: .circle)
      }
      .frame(width: 215, height: 245)
      .overlay(alignment: .bottomTrailing) {
        if let seconds = message.durationSeconds {
          Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(MeetPRSpacing.xs)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: MeetPRRadius.sm))
            .padding(MeetPRSpacing.sm)
        }
      }
      .overlay(alignment: .bottomLeading) {
        if message.videoURL == nil {
          Text(ChatVideoStrings.unavailable)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(MeetPRSpacing.sm)
            .background(.black.opacity(0.65))
        }
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(ChatVideoStrings.video)
    .accessibilityIdentifier("chat.video.message")
  }
}
