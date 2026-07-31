import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct FeedbackVideoFailureCard: View {
  let retrying: Bool
  let retry: () -> Void

  var body: some View {
    VStack(spacing: MeetPRSpacing.md) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 26))
        .foregroundStyle(Color.MeetPR.amber)
      Text(ChatStrings.playbackFailed)
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.textPrimary)
        .multilineTextAlignment(.center)
      Button(action: retry) {
        Text(retrying ? ChatStrings.refreshing : ChatStrings.retry)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(Color.MeetPR.goldCTA)
          .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      }
      .buttonStyle(.plain)
      .disabled(retrying)
    }
    .padding(MeetPRSpacing.lg)
    .frame(maxWidth: 280)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.lg)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
  }
}
