import DesignSystem
import SwiftUI

@MainActor
struct VideoFeedbackHeader: View {
  let studentName: String
  let exerciseName: String
  let meta: String
  let queuePosition: String?
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Button(action: dismiss) {
        Image(systemName: "chevron.left")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.94))
      .meetPRCardSurface(.card, cornerRadius: MeetPRRadius.pill)
      .accessibilityLabel(CoachVideoFeedbackStrings.back)
      .accessibilityIdentifier("coach.video.back")

      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(
          CoachVideoFeedbackStrings.title(
            studentName: studentName,
            exerciseName: exerciseName
          )
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineLimit(1)
        Text(meta)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if let queuePosition {
        Text(queuePosition)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .monospacedDigit()
      }
    }
    .padding(.top, MeetPRSpacing.space1)
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.bottom, MeetPRSpacing.space3)
    .background(Color.MeetPR.bgBase)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: MeetPRSpacing.point1)
    }
  }
}
