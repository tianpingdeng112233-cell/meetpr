import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthHistoryStatsCard: View {
  let stats: GrowthHistoryStats
  let isZeroTraining: Bool

  var body: some View {
    HStack {
      stat(
        StudentStrings.localized(.trainingHistoryView018), stats.trainingSessionCount.formatted())
      stat(StudentStrings.localized(.trainingHistoryView019), stats.trainingWeekCount.formatted())
      stat(
        StudentStrings.localized(.trainingHistoryView020),
        NSDecimalNumber(decimal: stats.totalVolumeKg).doubleValue.formatted(
          .number.grouping(.automatic).precision(.fractionLength(0))
        ),
        unit: "kg"
      )
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func stat(_ label: String, _ value: String, unit: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point2) {
        Text(isZeroTraining ? "—" : value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size30, weight: .bold))
          .foregroundStyle(
            isZeroTraining ? Color.MeetPR.textDim : Color.MeetPR.textPrimary
          )
          .minimumScaleFactor(0.65)
          .lineLimit(1)
        if let unit {
          Text(unit)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
            .foregroundStyle(
              isZeroTraining ? Color.MeetPR.textDim : Color.MeetPR.textMuted
            )
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
