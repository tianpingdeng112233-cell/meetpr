import CoreModels
import DesignSystem
import SwiftUI

public struct ChatPendingVideoCard: View {
  private let video: ChatVideoFile
  private let progress: Double?

  public init(video: ChatVideoFile, progress: Double?) {
    self.video = video
    self.progress = progress
  }

  public var body: some View {
    ZStack {
      Color.MeetPR.surfaceRaised
      if let data = video.posterData {
        #if os(iOS)
          if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
          }
        #elseif os(macOS)
          if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFill()
          }
        #endif
      }
      if let progress {
        Color.black.opacity(0.45)
        VStack(spacing: MeetPRSpacing.sm) {
          Text(progress.formatted(.percent.precision(.fractionLength(0))))
            .font(.body.monospacedDigit())
          ProgressView(value: progress)
            .tint(Color.MeetPR.gold500)
            .frame(width: 130)
        }
        .foregroundStyle(.white)
      } else {
        Image(systemName: "video.fill")
          .font(.title2).foregroundStyle(.white)
      }
    }
    .frame(width: 187, height: 215)
    .overlay(alignment: .bottomTrailing) {
      if let seconds = video.durationSeconds {
        Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.white)
          .padding(MeetPRSpacing.xs)
          .background(.black.opacity(0.6), in: .rect(cornerRadius: MeetPRRadius.sm))
          .padding(MeetPRSpacing.sm)
      }
    }
    .clipped()
    .accessibilityLabel(ChatVideoStrings.video)
  }
}
