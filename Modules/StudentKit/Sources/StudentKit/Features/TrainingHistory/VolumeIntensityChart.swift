import Charts
import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct VolumeIntensityChart: View {
  let buckets: [WeeklyProgressMetric]

  var body: some View {
    if buckets.isEmpty {
      ContentUnavailableView(
        "还没有训练记录",
        systemImage: "chart.bar.xaxis",
        description: Text("完成训练后会显示每周容量和平均 RPE")
      )
      .frame(maxWidth: .infinity, minHeight: 240)
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    } else {
      VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
        Chart {
          ForEach(buckets) { bucket in
            BarMark(
              x: .value("周", bucket.weekStart, unit: .weekOfYear),
              y: .value("训练容量", volumeValue(for: bucket))
            )
            .foregroundStyle(
              LinearGradient(
                colors: [Color.MeetPR.gold400, Color.MeetPR.gold700.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          }

          ForEach(rpeBuckets) { bucket in
            if let avgRPE = bucket.avgRPE {
              LineMark(
                x: .value("周", bucket.weekStart, unit: .weekOfYear),
                y: .value("平均 RPE", normalizedRPE(avgRPE))
              )
              .foregroundStyle(Color.MeetPR.bgBase)
              .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
              .interpolationMethod(.catmullRom)

              LineMark(
                x: .value("周", bucket.weekStart, unit: .weekOfYear),
                y: .value("平均 RPE", normalizedRPE(avgRPE))
              )
              .foregroundStyle(Color.MeetPR.chartLine)
              .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
              .interpolationMethod(.catmullRom)

              PointMark(
                x: .value("周", bucket.weekStart, unit: .weekOfYear),
                y: .value("平均 RPE", normalizedRPE(avgRPE))
              )
              .foregroundStyle(Color.MeetPR.chartLine)
              .symbolSize(22)
            }
          }
        }
        .chartYScale(domain: 0...volumeScale)
        .chartYAxis {
          AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Color.MeetPR.borderDefault)
            AxisValueLabel {
              if let kilograms = value.as(Double.self) {
                Text(kilograms, format: .number.precision(.fractionLength(0)))
                  .font(.MeetPR.mono(size: 9, weight: .medium))
                  .foregroundStyle(Color.MeetPR.textMuted)
              }
            }
          }

          AxisMarks(position: .trailing, values: rpeAxisValues) { value in
            AxisValueLabel {
              if let scaled = value.as(Double.self) {
                Text(rpeAxisLabel(for: scaled))
                  .font(.MeetPR.mono(size: 9, weight: .medium))
                  .foregroundStyle(Color.MeetPR.chartLine)
              }
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: .automatic(desiredCount: 4)) { value in
            AxisValueLabel {
              if let date = value.as(Date.self) {
                Text(date, format: .dateTime.month(.defaultDigits).day())
                  .font(.MeetPR.mono(size: 9, weight: .medium))
                  .foregroundStyle(Color.MeetPR.textMuted)
              }
            }
          }
        }
        .frame(height: 172)

        VolumeIntensityLegend()
      }
      .padding(MeetPRSpacing.md)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
      .accessibilityLabel("容量和平均 RPE 趋势图")
    }
  }

  private var rpeBuckets: [WeeklyProgressMetric] {
    buckets.filter { $0.avgRPE != nil }
  }

  private var rpeAxisValues: [Double] {
    [0, volumeScale / 2, volumeScale]
  }

  private var volumeScale: Double {
    let maxVolume = buckets.map(volumeValue(for:)).max() ?? 0
    return max(maxVolume * 1.15, 100)
  }

  private func normalizedRPE(_ rpe: Double) -> Double {
    let clampedRPE = min(max(rpe, 0), 10)
    return (clampedRPE / 10) * volumeScale
  }

  private func rpeAxisLabel(for scaledValue: Double) -> String {
    let rpe = (scaledValue / volumeScale) * 10
    return rpe.formatted(.number.precision(.fractionLength(0)))
  }

  private func volumeValue(for bucket: WeeklyProgressMetric) -> Double {
    NSDecimalNumber(decimal: bucket.volumeKg).doubleValue
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct VolumeIntensityLegend: View {
  var body: some View {
    HStack(spacing: MeetPRSpacing.base) {
      LegendSwatch(color: Color.MeetPR.gold500, label: "训练容量 kg")
      LegendSwatch(color: Color.MeetPR.chartLine, label: "平均 RPE")
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct LegendSwatch: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.xs) {
      RoundedRectangle(cornerRadius: MeetPRRadius.point2)
        .fill(color)
        .frame(width: 12, height: 8)
      Text(label)
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }
}
