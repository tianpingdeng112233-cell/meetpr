import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthComparisonCard: View {
  let presentation: GrowthComparisonPresentation

  var body: some View {
    VStack(spacing: MeetPRSpacing.point15) {
      HStack(alignment: .bottom) {
        total(
          title: StudentStrings.localized(.trainingHistoryView015),
          value: presentation.estimatedTotalKg.map(Self.weight) ?? "—",
          color: Color.MeetPR.textPrimary,
          alignment: .leading
        )
        Rectangle()
          .fill(Color.MeetPR.borderStrong)
          .frame(width: 1, height: MeetPRSpacing.point34)
        total(
          title: StudentStrings.localized(.trainingHistoryView016),
          value: presentation.trainingTotalKg.map(Self.weight) ?? "—",
          color: Color.MeetPR.textMuted,
          alignment: .trailing
        )
      }

      ForEach(presentation.rows) { row in
        VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
          HStack {
            Text(row.family.studentDisplayName)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
              .foregroundStyle(Color.MeetPR.textPrimary)
            Spacer()
            Text(rowValue(row))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.MeetPR.bgInset)
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [Color.MeetPR.goldBarDeep, Color.MeetPR.gold500],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: proxy.size.width * row.progress)
            }
          }
          .frame(height: MeetPRSpacing.space2)
          if row.hasExceededTrainingBaseline, let percentage = row.percentage {
            Label(
              StudentStrings.replacing(.trainingHistoryView017, values: ["\(percentage)"]),
              systemImage: "checkmark"
            )
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(Color.MeetPR.success)
          }
        }
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func total(
    title: String,
    value: String,
    color: Color,
    alignment: HorizontalAlignment
  ) -> some View {
    VStack(alignment: alignment, spacing: MeetPRSpacing.point3) {
      Text(title)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point3) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size28, weight: .bold))
        Text("kg")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
  }

  private func rowValue(_ row: GrowthComparisonRow) -> String {
    let estimated = row.estimatedOneRepMaxKg.map(Self.weight) ?? "—"
    let training = row.trainingOneRepMaxKg.map(Self.weight) ?? "—"
    return "\(estimated) / \(training) kg"
  }

  private static func weight(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
  }

  private static func weight(_ value: Decimal) -> String {
    UnitDisplay.plainString(value)
  }
}
