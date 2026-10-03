import CoreModels
import DesignSystem
import SwiftUI

struct TrainingDayPreview: View {
  let presentation: TodayWorkoutPresentation
  let cursorDay: StudentPlanDay?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      Text(TrainingSequenceText.recommendation(presentation.day.scheduledDate))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.goldText)
      Text(TrainingSequenceText.dayName(presentation.day))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(TrainingSequenceText.exerciseSummary(presentation.day))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)

      ForEach(presentation.exercises) { exercise in
        TodayWorkoutActionSummaryRow(exercise: exercise)
      }

      if let cursorDay {
        Text(TrainingSequenceText.unlockMessage(after: cursorDay))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .padding(MeetPRSpacing.space4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bgInset, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}
