import DesignSystem
import SwiftUI

@MainActor
struct VideoSetInfoCard: View {
  let info: VideoSetInfo

  var body: some View {
    HStack(spacing: 0) {
      VideoSetMetric(
        label: CoachVideoFeedbackStrings.weight,
        value: info.weightText,
        unit: CoachVideoFeedbackStrings.kilograms
      )
      divider
      VideoSetMetric(
        label: CoachVideoFeedbackStrings.reps,
        value: CoachVideoFeedbackStrings.repsValue(info.reps)
      )
      .padding(.leading, MeetPRSpacing.point14)
      divider
      VideoSetMetric(
        label: CoachVideoFeedbackStrings.rpe,
        value: info.rpeText ?? CoachVideoFeedbackStrings.missingValue
      )
      .padding(.leading, MeetPRSpacing.point14)
      divider
      VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
        Text(CoachVideoFeedbackStrings.setOrder)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
        Text(CoachVideoFeedbackStrings.setNumber(info.displaySetNumber))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, MeetPRSpacing.point14)
    }
    .padding(MeetPRSpacing.point15)
    .meetPRCardSurface(.card)
    .accessibilityIdentifier("coach.video.setInfo")
  }

  private var divider: some View {
    Rectangle()
      .fill(Color.MeetPR.borderDefault)
      .frame(width: MeetPRSpacing.point1)
  }
}

@MainActor
private struct VideoSetMetric: View {
  let label: String
  let value: String
  let unit: String?

  init(label: String, value: String, unit: String? = nil) {
    self.label = label
    self.value = value
    self.unit = unit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textTertiary)
      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point3) {
        Text(value)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size22))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        if let unit {
          Text(unit)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
