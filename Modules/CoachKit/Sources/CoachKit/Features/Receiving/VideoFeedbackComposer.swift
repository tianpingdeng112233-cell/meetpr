import DesignSystem
import SwiftUI

@MainActor
struct VideoFeedbackComposer: View {
  @Binding var text: String
  let studentName: String
  let send: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      TextField(
        CoachVideoFeedbackStrings.feedbackPlaceholder(studentName: studentName),
        text: $text
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(.vertical, MeetPRSpacing.space3)
      .accessibilityIdentifier("coach.video.feedbackInput")

      Button(action: send) {
        Text(CoachVideoFeedbackStrings.send)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.inkOnCTAFill)
          .padding(.vertical, MeetPRSpacing.point10)
          .padding(.horizontal, MeetPRSpacing.space4)
          .background(Color.MeetPR.textPrimary)
          .clipShape(.rect(cornerRadius: MeetPRRadius.control))
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.96))
      .accessibilityIdentifier("coach.video.send")
    }
    .padding(.leading, MeetPRSpacing.point14)
    .padding(.trailing, MeetPRSpacing.point6)
    .padding(.vertical, MeetPRSpacing.point6)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
    }
    .meetPRCardSurface(.card)
  }
}
