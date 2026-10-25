import DesignSystem
import SwiftUI

struct CompletedVideoPlayerHeader: View {
  let close: () -> Void
  let onReview: (() -> Void)?

  var body: some View {
    HStack(alignment: .top) {
      Button(action: close) {
        Image(systemName: "xmark")
          .font(.MeetPR.bodyEmphasis)
          .frame(width: MeetPRSpacing.minimumHitTarget, height: MeetPRSpacing.minimumHitTarget)
          .background(Color.MeetPR.completedVideoCloseFill, in: .circle)
      }
      .accessibilityLabel(String(localized: "student.completedVideo.close", bundle: .module))
      .accessibilityIdentifier("completedVideo.close")
      Spacer(minLength: MeetPRSpacing.sm)
      if let onReview {
        Button(action: onReview) {
          HStack(spacing: MeetPRSpacing.space1) {
            Text(String(localized: "student.completedVideo.reviewed", bundle: .module))
            Image(systemName: "chevron.right").opacity(0.7)
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
          .padding(.horizontal, MeetPRSpacing.space3)
          .frame(minHeight: MeetPRSpacing.point30)
          .background(Color.MeetPR.completedVideoReviewFill, in: .capsule)
          .overlay { Capsule().stroke(Color.MeetPR.completedVideoReviewBorder, lineWidth: 1) }
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          .contentShape(.rect)
        }
        .accessibilityIdentifier("completedVideo.review")
      }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.white)
    .padding(MeetPRSpacing.sm)
  }
}
