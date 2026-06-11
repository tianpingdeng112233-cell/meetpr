import Charts
import SwiftUI

/// Atomic e1RM line chart (spec 028, reused by CoachKit in spec 029).
/// DesignSystem stays model-free: callers map their domain history into
/// `E1RMChartPoint` values.
public struct E1RMChartPoint: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let date: Date
  public let e1RMKg: Double

  public init(id: UUID, date: Date, e1RMKg: Double) {
    self.id = id
    self.date = date
    self.e1RMKg = e1RMKg
  }
}

@MainActor
public struct E1RMChart: View {
  private let points: [E1RMChartPoint]
  private let onSelect: ((E1RMChartPoint) -> Void)?

  public init(points: [E1RMChartPoint], onSelect: ((E1RMChartPoint) -> Void)? = nil) {
    self.points = points.sorted { $0.date < $1.date }
    self.onSelect = onSelect
  }

  public var body: some View {
    Chart(points) { point in
      LineMark(
        x: .value("日期", point.date),
        y: .value("e1RM", point.e1RMKg)
      )
      .foregroundStyle(Color.MeetPR.brandRed)
      .interpolationMethod(.monotone)

      PointMark(
        x: .value("日期", point.date),
        y: .value("e1RM", point.e1RMKg)
      )
      .foregroundStyle(Color.MeetPR.brandRed)
      .symbolSize(36)
    }
    .chartYScale(domain: yDomain)
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisGridLine().foregroundStyle(Color.MeetPR.fgTertiary.opacity(0.25))
        AxisValueLabel {
          if let kilograms = value.as(Double.self) {
            Text("\(Int(kilograms))")
              .font(Font.MeetPR.monoLabel)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(date, format: .dateTime.month(.defaultDigits).day())
              .font(Font.MeetPR.monoLabel)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        Rectangle()
          .fill(Color.clear)
          .contentShape(Rectangle())
          .onTapGesture { location in
            guard let onSelect else { return }
            let plotOrigin = geometry[proxy.plotFrame!].origin
            let xInPlot = location.x - plotOrigin.x
            guard let tappedDate: Date = proxy.value(atX: xInPlot) else { return }
            guard
              let nearest = points.min(by: {
                abs($0.date.timeIntervalSince(tappedDate))
                  < abs($1.date.timeIntervalSince(tappedDate))
              })
            else { return }
            onSelect(nearest)
          }
      }
    }
    .accessibilityLabel("e1RM 成长曲线，共 \(points.count) 个数据点")
  }

  private var yDomain: ClosedRange<Double> {
    guard let min = points.map(\.e1RMKg).min(),
      let max = points.map(\.e1RMKg).max()
    else { return 0...100 }
    let padding = Swift.max((max - min) * 0.15, 5)
    return (min - padding)...(max + padding)
  }
}
