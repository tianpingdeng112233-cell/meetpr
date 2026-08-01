import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoPlayerChrome: View {
  let rateText: String
  let close: () -> Void
  let cycleRate: () -> Void

  var body: some View {
    HStack {
      Button(action: close) {
        Image(systemName: "xmark")
          .bold()
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
          }
      }
      .accessibilityLabel(ChatStrings.closePlayback)

      Eyebrow(ChatStrings.videoPlayback, color: .white.opacity(0.85))
        .padding(.leading, MeetPRSpacing.xs)

      Spacer()

      Button(action: cycleRate) {
        Text(rateText)
          .font(.system(size: 14, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white)
          .padding(.horizontal, MeetPRSpacing.md)
          .frame(height: 36)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay {
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
          }
      }
      .accessibilityLabel("\(ChatStrings.playbackSpeed) \(rateText)")
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
  }
}
