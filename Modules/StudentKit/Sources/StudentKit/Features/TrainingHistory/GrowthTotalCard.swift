import Charts
import DesignSystem
import SwiftUI

struct GrowthTotalCard: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let presentation: GrowthTotalPresentation
  let range: GrowthTimeRange
  let onCycleRange: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      HStack {
        Text(StudentStrings.localized(.progressTotalTitle))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        GrowthTotalRangeControl(range: range, onCycleRange: onCycleRange)
      }
      let valueLayout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: MeetPRSpacing.space1))
        : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1))
      valueLayout {
        HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
          Text(
            presentation.currentKg.map { $0.formatted(.number.precision(.fractionLength(1))) }
              ?? "—"
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size38, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          Text("kg")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        .layoutPriority(1)
        if presentation.state == .chart, let delta = presentation.deltaKg {
          Text(
            (delta < 0 ? "−" : "+") + abs(delta).formatted(.number.precision(.fractionLength(1)))
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.goldText)
          .frame(
            maxWidth: .infinity,
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
      }
      switch presentation.state {
      case .chart:
        GrowthTotalChart(samples: presentation.samples)
          .aspectRatio(320 / 118, contentMode: .fit)
          .padding(.top, MeetPRSpacing.space2)
      case .missing:
        VStack(spacing: MeetPRSpacing.space3) {
          Text(StudentStrings.localized(.progressTotalEmpty))
          Text(
            StudentStrings.replacing(
              .progressMissing,
              values: [StudentStrings.listSeparated(presentation.missing.map(\.studentDisplayName))]
            ))
        }
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.xl)
      case .sparse:
        GrowthWindowSparseTrendState(
          message: GrowthE1RMCardCopy.windowSparseMessage(window: range.displayName)
        )
        .frame(minHeight: 126)
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.card))
  }
}

private struct GrowthTotalRangeControl: View {
  let range: GrowthTimeRange
  let onCycleRange: () -> Void

  var body: some View {
    Button(action: onCycleRange) {
      HStack(spacing: MeetPRSpacing.space1) {
        Text(range.displayName)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Image(systemName: "chevron.down")
          .font(.system(size: MeetPRFontMetrics.size10, weight: .bold))
          .foregroundStyle(Color.MeetPR.gold500)
      }
      .padding(.horizontal, MeetPRSpacing.point10)
      .frame(minHeight: MeetPRSpacing.point22)
      .background(Color.MeetPR.surfaceElevated, in: .capsule)
      .overlay { Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1) }
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .contentShape(.rect)
    }
    .accessibilityLabel(
      StudentStrings.replacing(
        .growthE1Rmcard001,
        values: [StudentStrings.localized(.progressTotal), range.displayName])
    )
    .accessibilityHint(StudentStrings.localized(.growthE1Rmcard002))
  }
}

private struct GrowthTotalChart: View {
  let samples: [GrowthTotalPoint]

  var body: some View {
    Chart(samples, id: \.date) { sample in
      LineMark(x: .value("Date", sample.date), y: .value("kg", sample.valueKg))
        .foregroundStyle(Color.MeetPR.gold500)
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
      PointMark(x: .value("Date", sample.date), y: .value("kg", sample.valueKg))
        .foregroundStyle(Color.MeetPR.gold500)
        .symbolSize(sample == samples.last ? 40 : 28)
      if sample != samples.last {
        PointMark(x: .value("Date", sample.date), y: .value("kg", sample.valueKg))
          .foregroundStyle(Color.MeetPR.surfaceCard)
          .symbolSize(12)
      }
    }
    .chartYScale(domain: domain)
    .chartYAxis {
      AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
        AxisGridLine().foregroundStyle(Color.MeetPR.borderSubtle)
        AxisValueLabel().foregroundStyle(Color.MeetPR.textTertiary)
      }
    }
    .chartXAxis {
      AxisMarks(values: [samples.first?.date, samples.last?.date].compactMap { $0 }) { _ in
        AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }

  private var domain: ClosedRange<Double> {
    let values = samples.map(\.valueKg)
    let minimum = values.min() ?? 0
    let maximum = values.max() ?? minimum
    let span = max(maximum - minimum, 1)
    return (minimum - span * 0.35 - 1)...(maximum + span * 0.12 + 1)
  }
}
