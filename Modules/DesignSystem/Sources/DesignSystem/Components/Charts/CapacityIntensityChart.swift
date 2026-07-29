import Charts
import SwiftUI

public struct CapacityIntensityPoint: Identifiable, Sendable {
  public let id: UUID
  public let date: Date
  public let volumeKilograms: Double
  public let averageRPE: Double

  public init(
    id: UUID = UUID(),
    date: Date,
    volumeKilograms: Double,
    averageRPE: Double
  ) {
    self.id = id
    self.date = date
    self.volumeKilograms = volumeKilograms
    self.averageRPE = averageRPE
  }
}

@MainActor
public struct CapacityIntensityChart: View {
  private let points: [CapacityIntensityPoint]

  public init(points: [CapacityIntensityPoint]) {
    self.points = points.sorted { $0.date < $1.date }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Chart(points) { point in
        BarMark(
          x: .value("日期", point.date, unit: .day),
          y: .value("训练容量", point.volumeKilograms)
        )
        .foregroundStyle(
          LinearGradient(
            colors: [
              Color.MeetPR.gold400,
              Color.MeetPR.goldBarDeep.opacity(0.28),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .cornerRadius(MeetPRRadius.point2)

        LineMark(
          x: .value("日期", point.date, unit: .day),
          y: .value("平均 RPE", normalizedRPE(point.averageRPE))
        )
        .foregroundStyle(Color.MeetPR.bgBase)
        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .interpolationMethod(.monotone)

        LineMark(
          x: .value("日期", point.date, unit: .day),
          y: .value("平均 RPE", normalizedRPE(point.averageRPE))
        )
        .foregroundStyle(Color.MeetPR.chartLine)
        .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        .interpolationMethod(.monotone)

        PointMark(
          x: .value("日期", point.date, unit: .day),
          y: .value("平均 RPE", normalizedRPE(point.averageRPE))
        )
        .foregroundStyle(Color.MeetPR.chartLine)
        .symbolSize(22)
      }
      .chartYAxis {
        AxisMarks(values: .automatic(desiredCount: 3)) { value in
          AxisGridLine().foregroundStyle(Color.MeetPR.borderDefault)
          AxisValueLabel {
            if let volume = value.as(Double.self) {
              Text(volume.formatted(.number.notation(.compactName)))
                .font(.MeetPR.mono(size: 9, weight: .medium))
                .foregroundStyle(Color.MeetPR.textMuted)
            }
          }
        }
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 5)) { value in
          AxisValueLabel {
            if let date = value.as(Date.self) {
              Text(date, format: .dateTime.month(.twoDigits).day(.twoDigits))
                .font(.MeetPR.mono(size: 9, weight: .medium))
                .foregroundStyle(Color.MeetPR.textMuted)
            }
          }
        }
      }
      .frame(height: 172)

      HStack(spacing: MeetPRSpacing.base) {
        legend(title: "训练容量 kg", color: Color.MeetPR.gold500, isCircle: false)
        legend(title: "平均 RPE", color: Color.MeetPR.chartLine, isCircle: true)
      }
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.top, MeetPRSpacing.point15)
    .padding(.bottom, MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private func normalizedRPE(_ value: Double) -> Double {
    guard let maximum = points.map(\.volumeKilograms).max(), maximum > 0 else {
      return 0
    }
    return min(10, max(0, value)) / 10 * maximum
  }

  private func legend(title: String, color: Color, isCircle: Bool) -> some View {
    HStack(spacing: MeetPRSpacing.point6) {
      if isCircle {
        Circle()
          .fill(color)
          .frame(width: 9, height: 9)
      } else {
        RoundedRectangle(cornerRadius: MeetPRRadius.point2)
          .fill(color)
          .frame(width: 9, height: 9)
      }
      Text(title)
        .font(.MeetPR.mono(size: 11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
  }
}
