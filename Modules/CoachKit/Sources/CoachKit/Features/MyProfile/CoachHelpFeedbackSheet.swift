import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct CoachHelpFeedbackSheet: View {
  var body: some View {
    CoachProfileSheetScaffold(
      title: CoachMyProfileStrings.help,
      subtitle: CoachMyProfileStrings.helpSubtitle
    ) {
      VStack(spacing: MeetPRSpacing.zero) {
        ForEach(CoachMyProfileStrings.frequentlyAskedQuestions, id: \.question) { item in
          VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
            Text(item.question)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Text(item.answer)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textTertiary)
              .lineSpacing(MeetPRSpacing.point7)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, MeetPRSpacing.space4)
          .padding(.vertical, MeetPRSpacing.point14)
          .overlay(alignment: .top) {
            if item.question
              != CoachMyProfileStrings.frequentlyAskedQuestions.first?.question
            {
              Rectangle()
                .fill(Color.MeetPR.borderHairline)
                .frame(height: MeetPRSpacing.point1)
            }
          }
        }
      }
      .meetPRCardSurface(.card)

      Text(CoachMyProfileStrings.contactUs)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(Color.MeetPR.surfaceCard)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.point15)
        .background(Color.MeetPR.textPrimary, in: .capsule)
        .opacity(0.35)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("coach.profile.contactUnavailable")

      Text(CoachMyProfileStrings.contactHours)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textDisabled)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
  }
}
