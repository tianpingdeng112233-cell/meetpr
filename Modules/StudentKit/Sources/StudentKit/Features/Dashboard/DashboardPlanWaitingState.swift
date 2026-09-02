import DesignSystem
import SwiftUI

/// Design source:
/// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
/// scene 04, CTA dashed slot and weekly-summary card.
@available(iOS 17.0, macOS 14.0, *)
struct DashboardPlanWaitingState: View {
  let coachName: String
  let nextWeekIndex: Int
  let summary: DashboardWeekSummary
  let onMessageCoach: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point13) {
      VStack(spacing: MeetPRSpacing.point11) {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "calendar")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size22, weight: .medium))
            .foregroundStyle(Color.MeetPR.textMuted)
            .frame(width: 52, height: 52)
            .overlay {
              RoundedRectangle(cornerRadius: 16)
                .stroke(
                  Color.MeetPR.borderStrong,
                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
            }

          Circle()
            .fill(Color.MeetPR.gold500)
            .frame(width: 16, height: 16)
            .overlay {
              Image(systemName: "plus")
                .font(.MeetPR.system(size: MeetPRFontMetrics.size9, weight: .bold))
                .foregroundStyle(Color.MeetPR.bgBase)
            }
            .offset(x: 4, y: -4)
        }

        Text(
          StudentStrings.replacing(
            .dashboardPlanWaitingState001, values: ["\(coachName)", "\(nextWeekIndex)"])
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)

        (Text(StudentStrings.localized(.dashboardPlanWaitingState002))
          + Text(StudentStrings.localized(.dashboardPlanWaitingState003)).foregroundStyle(
            Color.MeetPR.textSecondary)
          + Text(StudentStrings.localized(.dashboardPlanWaitingState004)))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
          .multilineTextAlignment(.center)
          .lineSpacing(4)

        Button(StudentStrings.localized(.dashboardPlanWaitingState005), action: onMessageCoach)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.horizontal, 17)
          .frame(minHeight: 38)
          .overlay {
            Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
          }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 22)
      .frame(maxWidth: .infinity)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: 16))

      Text(
        StudentStrings.replacing(
          .dashboardPlanWaitingState006, values: ["\(max(1, nextWeekIndex - 1))"])
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
      .foregroundStyle(Color.MeetPR.textSecondary)

      HStack {
        summaryStat(
          label: StudentStrings.localized(.dashboardPlanWaitingState007),
          value: summary.completedTrainingDays.formatted(),
          suffix: "/\(summary.totalTrainingDays)"
        )
        summaryStat(
          label: StudentStrings.localized(.dashboardPlanWaitingState008), value: volumeValue,
          suffix: volumeUnit)
        summaryStat(
          label: StudentStrings.localized(.dashboardPlanWaitingState009),
          value: summary.newPRCount.formatted(),
          suffix: nil,
          isGold: true
        )
      }
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: 16))
    }
  }

  private func summaryStat(
    label: String,
    value: String,
    suffix: String?,
    isGold: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size28, weight: .bold))
          .foregroundStyle(isGold ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
          .shadow(
            color: isGold && colorScheme == .dark
              ? Color.MeetPR.goldRGB.opacity(0.4)
              : .clear,
            radius: 7
          )
        if let suffix {
          Text(suffix)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var volumeValue: String {
    let kilograms = NSDecimalNumber(decimal: summary.totalVolumeKg).doubleValue
    guard kilograms >= 1_000 else {
      return kilograms.formatted(.number.precision(.fractionLength(0)))
    }
    return (kilograms / 1_000).formatted(.number.precision(.fractionLength(1)))
  }

  private var volumeUnit: String {
    summary.totalVolumeKg >= 1_000 ? "t" : "kg"
  }
}
