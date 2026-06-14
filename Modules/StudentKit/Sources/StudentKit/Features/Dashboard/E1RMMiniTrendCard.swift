import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct E1RMMiniTrendCard: View {
  let state: DashboardE1RMTrendViewModel.State

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      content
    }
    .modifier(DashboardCard())
  }

  @ViewBuilder
  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("三大项 e1RM")
        .font(.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Spacer()
      if let headline {
        Text(
          "\(headline.label) · \(headline.family.studentDisplayName) "
            + "\(StudentFormatting.kilograms(headline.valueKg))kg"
        )
        .font(.caption)
        .foregroundStyle(Color.MeetPR.brandRed)
        .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity, minHeight: 96)
    case .error:
      Text("趋势加载失败")
        .font(.subheadline)
        .foregroundStyle(Color.MeetPR.fgTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
    case .loaded(let presentation):
      if presentation.hasHistory {
        VStack(spacing: 10) {
          ForEach(presentation.rows) { row in
            E1RMMiniTrendRowView(row: row)
          }
        }
      } else {
        Text("练几次就有趋势了")
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.fgTertiary)
          .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
      }
    }
  }

  private var headline: DashboardE1RMHeadline? {
    guard case .loaded(let presentation) = state else {
      return nil
    }
    return presentation.headline
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct E1RMMiniTrendRowView: View {
  let row: DashboardE1RMTrendRow

  var body: some View {
    HStack(spacing: 10) {
      Text(row.family.studentDisplayName)
        .font(.caption)
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .frame(width: 34, alignment: .leading)
      MiniSparkline(points: row.points)
        .frame(height: 28)
      Text(valueText)
        .font(.caption.monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 52, alignment: .trailing)
    }
  }

  private var valueText: String {
    guard let latest = row.latestPoint else {
      return "暂无"
    }
    return "\(StudentFormatting.kilograms(latest.e1RMKg))kg"
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MiniSparkline: View {
  let points: [E1RMHistoryPoint]

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Rectangle()
          .fill(Color.MeetPR.surface3)
          .frame(height: 1)
        path(in: proxy.size)
          .stroke(
            points.isEmpty ? Color.MeetPR.fgTertiary.opacity(0.35) : Color.MeetPR.brandRed,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
      }
    }
    .accessibilityHidden(true)
  }

  private func path(in size: CGSize) -> Path {
    let sortedPoints = points.sorted { $0.computedAt < $1.computedAt }
    guard !sortedPoints.isEmpty else {
      return Path()
    }
    let values = sortedPoints.map(\.e1RMKg)
    let minValue = values.min() ?? 0
    let maxValue = values.max() ?? minValue
    let span = Swift.max(maxValue - minValue, 1)
    let layout = SparklineLayout(
      count: sortedPoints.count, minValue: minValue, span: span, size: size)
    return Path { path in
      for (index, point) in sortedPoints.enumerated() {
        let location = location(for: point, index: index, layout: layout)
        if index == 0 {
          path.move(to: location)
        } else {
          path.addLine(to: location)
        }
      }
    }
  }

  private func location(
    for point: E1RMHistoryPoint,
    index: Int,
    layout: SparklineLayout
  ) -> CGPoint {
    let xPosition =
      layout.count == 1
      ? layout.size.width / 2
      : CGFloat(index) * layout.size.width / CGFloat(layout.count - 1)
    let normalized = (point.e1RMKg - layout.minValue) / layout.span
    let yPosition = layout.size.height - CGFloat(normalized) * layout.size.height
    return CGPoint(x: xPosition, y: yPosition)
  }
}

private struct SparklineLayout {
  let count: Int
  let minValue: Double
  let span: Double
  let size: CGSize
}
