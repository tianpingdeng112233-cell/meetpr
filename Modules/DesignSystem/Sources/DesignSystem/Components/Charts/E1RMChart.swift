import Charts
import SwiftUI

/// DesignSystem-safe mirror of an e1RM point's provenance. Callers translate
/// their domain model rather than making this target depend on CoreModels.
public enum E1RMChartPointOrigin: Hashable, Sendable {
  case logged
  case imported
}

/// Trust tier used to de-emphasize quarantined e1RM scatter points.
public enum E1RMChartPointConfidence: Hashable, Sendable {
  case normal
  case low
}

/// Atomic e1RM line chart (spec 028, reused by CoachKit in spec 029).
/// DesignSystem stays model-free: callers map their domain history into
/// `E1RMChartPoint` values.
public struct E1RMChartPoint: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let date: Date
  public let e1RMKg: Double
  public let origin: E1RMChartPointOrigin
  public let confidence: E1RMChartPointConfidence
  public let winnerPointID: UUID

  public init(
    id: UUID,
    date: Date,
    e1RMKg: Double,
    origin: E1RMChartPointOrigin = .logged,
    confidence: E1RMChartPointConfidence = .normal,
    winnerPointID: UUID? = nil
  ) {
    self.id = id
    self.date = date
    self.e1RMKg = e1RMKg
    self.origin = origin
    self.confidence = confidence
    self.winnerPointID = winnerPointID ?? id
  }
}

@MainActor
public struct E1RMChart: View {
  private let smoothed: [E1RMChartPoint]
  private let rawEligible: [E1RMChartPoint]
  private let onSelect: ((E1RMChartPoint) -> Void)?

  public init(points: [E1RMChartPoint], onSelect: ((E1RMChartPoint) -> Void)? = nil) {
    let sorted = points.sorted { $0.date < $1.date }
    smoothed = sorted
    rawEligible = sorted
    self.onSelect = onSelect
  }

  public init(
    smoothed: [E1RMChartPoint],
    rawEligible: [E1RMChartPoint],
    onSelect: ((E1RMChartPoint) -> Void)? = nil
  ) {
    self.smoothed = smoothed.sorted { $0.date < $1.date }
    self.rawEligible = rawEligible.sorted { $0.date < $1.date }
    self.onSelect = onSelect
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Chart {
        smoothedLine
        rawScatter
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
              guard let onSelect, let plotFrame = proxy.plotFrame else { return }
              let plotOrigin = geometry[plotFrame].origin
              let xInPlot = location.x - plotOrigin.x
              guard let tappedDate: Date = proxy.value(atX: xInPlot) else { return }
              guard
                let nearest = smoothed.min(by: {
                  abs($0.date.timeIntervalSince(tappedDate))
                    < abs($1.date.timeIntervalSince(tappedDate))
                })
              else { return }
              onSelect(nearest)
            }
        }
      }
      .accessibilityLabel("e1RM 成长曲线，共 \(smoothed.count) 个主线数据点")

      if containsImportedPoint {
        HStack(spacing: 6) {
          ImportedLegendDash()
            .stroke(
              Color.MeetPR.fgSecondary,
              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
            )
            .frame(width: 22, height: 1.5)
          Text("虚线 = 导入的历史记录")
            .font(Font.MeetPR.monoLabel)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
      }
    }
  }

  @ChartContentBuilder
  private var smoothedLine: some ChartContent {
    ForEach(lineSegments) { segment in
      ForEach(segment.points) { point in
        LineMark(
          x: .value("日期", point.date),
          y: .value("e1RM", point.e1RMKg),
          series: .value("线段", segment.id)
        )
        .foregroundStyle(lineColor(for: segment.origin))
        .lineStyle(lineStyle(for: segment.origin))
        .interpolationMethod(.monotone)
      }
    }
  }

  @ChartContentBuilder
  private var rawScatter: some ChartContent {
    ForEach(rawEligible) { point in
      PointMark(
        x: .value("日期", point.date),
        y: .value("e1RM", point.e1RMKg)
      )
      .foregroundStyle(scatterColor(for: point))
      .symbol(point.confidence == .low ? .diamond : .circle)
      .symbolSize(point.confidence == .low ? 24 : 36)
    }
  }

  private var lineSegments: [LineSegment] {
    guard smoothed.count > 1 else { return [] }
    return smoothed.indices.dropFirst().map { index in
      LineSegment(
        id: index,
        start: smoothed[index - 1],
        end: smoothed[index],
        origin: smoothed[index].origin
      )
    }
  }

  private func lineColor(for origin: E1RMChartPointOrigin) -> Color {
    switch origin {
    case .logged: Color.MeetPR.brandRed
    case .imported: Color.MeetPR.fgSecondary
    }
  }

  private func lineStyle(for origin: E1RMChartPointOrigin) -> StrokeStyle {
    switch origin {
    case .logged: StrokeStyle()
    case .imported: StrokeStyle(dash: [5, 3])
    }
  }

  private func scatterColor(for point: E1RMChartPoint) -> Color {
    let base = lineColor(for: point.origin)
    if point.confidence == .low {
      return base.opacity(0.35)
    }
    return point.origin == .imported ? base.opacity(0.65) : base
  }

  private var containsImportedPoint: Bool {
    smoothed.contains { $0.origin == .imported }
      || rawEligible.contains { $0.origin == .imported }
  }

  private var yDomain: ClosedRange<Double> {
    let values = (smoothed + rawEligible).map(\.e1RMKg)
    guard let min = values.min(), let max = values.max() else { return 0...100 }
    let padding = Swift.max((max - min) * 0.15, 5)
    return (min - padding)...(max + padding)
  }
}

private struct LineSegment: Identifiable {
  let id: Int
  let start: E1RMChartPoint
  let end: E1RMChartPoint
  let origin: E1RMChartPointOrigin

  var points: [E1RMChartPoint] { [start, end] }
}

/// Tiny dashed-line swatch so the imported-history legend shows the actual
/// stroke it refers to instead of describing a color in prose.
private struct ImportedLegendDash: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    return path
  }
}
