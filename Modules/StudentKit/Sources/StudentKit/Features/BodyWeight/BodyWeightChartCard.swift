import Charts
import DesignSystem
import SwiftUI

struct BodyWeightChartCard: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let presentation: BodyWeightPresentation
  let range: GrowthTimeRange
  let onCycleRange: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
      HStack {
        Text(StudentStrings.localized(.bodyWeightLatest))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        Button(action: onCycleRange) {
          HStack(spacing: MeetPRSpacing.space1) {
            Text(range.displayName)
            Image(systemName: "chevron.down")
          }
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .padding(.horizontal, MeetPRSpacing.point10)
          .padding(.vertical, MeetPRSpacing.space1)
          .background(Color.MeetPR.surfaceElevated, in: .capsule)
          .overlay { Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1) }
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
        }
        .accessibilityLabel(
          StudentStrings.replacing(.bodyWeightRangeLabel, values: [range.displayName]))
      }
      let layout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space1))
        : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1))
      layout {
        HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
          Text(presentation.currentKg.map { BodyWeightInput.text(kg: $0, unit: .kg) } ?? "—")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size38, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("kg")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size15))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        if let delta = presentation.deltaKg {
          Text((delta < 0 ? "−" : "+") + BodyWeightInput.text(kg: abs(delta), unit: .kg))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textSecondary)
            .frame(
              maxWidth: .infinity,
              alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
      }
      if presentation.state == .empty {
        Text(
          StudentStrings.localized(
            presentation.records.isEmpty ? .bodyWeightEmpty : .bodyWeightRangeEmpty)
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.xl)
      } else {
        BodyWeightChart(records: presentation.points)
          .aspectRatio(2, contentMode: .fit)
        if presentation.state == .single {
          Text(StudentStrings.localized(.bodyWeightSingle))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct BodyWeightChart: View {
  let records: [BodyWeightRecord]

  var body: some View {
    Chart(records) { record in
      if let date = DateOnly.date(from: record.recordedOn) {
        let value = NSDecimalNumber(decimal: record.weightKg).doubleValue
        LineMark(x: .value("Date", date), y: .value("kg", value))
          .foregroundStyle(Color.MeetPR.gold500)
          .lineStyle(StrokeStyle(lineWidth: 2.5))
        PointMark(x: .value("Date", date), y: .value("kg", value))
          .foregroundStyle(Color.MeetPR.gold500)
          .symbolSize(40)
          .annotation(position: .top) {
            if records.count == 1 {
              Text(BodyWeightInput.text(kg: record.weightKg, unit: .kg))
                .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
                .foregroundStyle(Color.MeetPR.textSecondary)
            }
          }
        if record.id != records.last?.id {
          PointMark(x: .value("Date", date), y: .value("kg", value))
            .foregroundStyle(Color.MeetPR.surfaceCard)
            .symbolSize(16)
        }
      }
    }
    .chartYScale(domain: domain)
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
        AxisGridLine().foregroundStyle(Color.MeetPR.borderSubtle)
        AxisValueLabel {
          if let kilograms = value.as(Double.self) {
            Text(kilograms.formatted(.number.precision(.fractionLength(2))))
          }
        }
        .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .chartXAxis {
      AxisMarks(values: endpointDates) { value in
        AxisValueLabel(
          format: .dateTime.month(.twoDigits).day(.twoDigits),
          anchor: records.count == 1 ? .top : (value.index == 0 ? .topLeading : .topTrailing)
        )
        .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }

  private var endpointDates: [Date] {
    Array(
      Set(
        [records.first?.recordedOn, records.last?.recordedOn]
          .compactMap { DateOnly.date(from: $0) })
    ).sorted()
  }

  private var domain: ClosedRange<Double> {
    let values = records.map { NSDecimalNumber(decimal: $0.weightKg).doubleValue }
    let minimum = values.min() ?? 0
    let maximum = values.max() ?? minimum
    let padding = max((maximum - minimum) * 0.2, 0.5)
    return (minimum - padding)...(maximum + padding)
  }
}
