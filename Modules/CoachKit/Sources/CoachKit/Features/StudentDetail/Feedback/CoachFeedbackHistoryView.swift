import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachFeedbackHistoryView: View {
  let feedback: [CoachFeedback]
  let days: [StudentPlanDay]
  let now: Date

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
        HStack {
          Text(CoachFeedbackStrings.recordCount(feedback.count))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)
          Spacer()
          Text(CoachFeedbackStrings.writeFromVideo)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textDisabled)
        }

        if feedback.isEmpty {
          Text(CoachFeedbackStrings.empty)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, MeetPRSpacing.point22)
        } else {
          ForEach(feedback) { item in
            feedbackCard(item)
          }
        }
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.bottom, MeetPRSpacing.point28)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
  }

  private func feedbackCard(_ item: CoachFeedback) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      HStack(spacing: MeetPRSpacing.space2) {
        Text(CoachStudentFormatting.relativeText(item.postedAt, now: now))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
        if let subject = subject(item) {
          Text(subject)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, MeetPRSpacing.space2)
            .padding(.vertical, MeetPRSpacing.point2)
            .overlay {
              Capsule()
                .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
            }
        }
      }
      Text(item.text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineSpacing(MeetPRSpacing.point7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.point14)
    .meetPRCardSurface(.card)
  }

  private func subject(_ item: CoachFeedback) -> String? {
    if let exerciseID = item.planExerciseID,
      let exercise = days.flatMap(\.exercises).first(where: { $0.id == exerciseID })
    {
      return exercise.exercise.name
    }
    if item.videoID != nil {
      return CoachFeedbackStrings.videoFeedback
    }
    return item.dayDate.map { date in
      date.formatted(
        .dateTime.month(.twoDigits).day(.twoDigits)
          .locale(Locale(identifier: "zh_Hans_CN"))
      )
    }
  }
}

enum CoachFeedbackStrings {
  static let writeFromVideo = CoachLocalization.localized("coach.feedback.writeFromVideo")
  static let empty = CoachLocalization.localized("coach.feedback.empty")
  static let videoFeedback = CoachLocalization.localized("coach.feedback.videoFeedback")

  static func recordCount(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.feedback.recordCount",
      values: ["count": count.formatted()]
    )
  }
}
