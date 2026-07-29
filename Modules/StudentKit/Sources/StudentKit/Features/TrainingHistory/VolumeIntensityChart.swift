import DesignSystem
import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct VolumeIntensityChart: View {
  let buckets: [WeeklyProgressMetric]
  var isUnlocked = true

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point9) {
      if isUnlocked, !buckets.isEmpty {
        GeometryReader { proxy in
          let geometry = VolumeChartGeometry(buckets: buckets, size: proxy.size)
          ZStack {
            Canvas { context, _ in
              drawGrid(context: &context, geometry: geometry)
              drawBars(context: &context, geometry: geometry)
              drawRPE(context: &context, geometry: geometry)
            }
            labels(geometry)
          }
        }
        .aspectRatio(320 / 172, contentMode: .fit)

        HStack(spacing: MeetPRSpacing.space4) {
          legend(title: "训练容量 kg", color: Color.MeetPR.gold500, isCircle: false)
          legend(title: "平均 RPE", color: Color.MeetPR.chartLine, isCircle: true)
        }
        .padding(.leading, MeetPRSpacing.point2)
      } else {
        GrowthTrendEmptyState()
          .frame(minHeight: 172)
      }
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.top, MeetPRSpacing.point15)
    .padding(.bottom, MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private func drawGrid(
    context: inout GraphicsContext,
    geometry: VolumeChartGeometry
  ) {
    for y in [18.0, 82.0] {
      var line = Path()
      line.move(to: geometry.point(x: 42, y: y))
      line.addLine(to: geometry.point(x: 300, y: y))
      context.stroke(line, with: .color(Color.MeetPR.surfaceRaised), lineWidth: 1)
    }
    var baseline = Path()
    baseline.move(to: geometry.point(x: 42, y: 146))
    baseline.addLine(to: geometry.point(x: 300, y: 146))
    context.stroke(baseline, with: .color(Color.MeetPR.borderStrong), lineWidth: 1)
  }

  private func drawBars(
    context: inout GraphicsContext,
    geometry: VolumeChartGeometry
  ) {
    for bar in geometry.bars {
      context.fill(
        bar,
        with: .linearGradient(
          Gradient(colors: [
            Color.MeetPR.gold400,
            Color.MeetPR.goldBarDeep.opacity(0.28),
          ]),
          startPoint: CGPoint(x: 0, y: geometry.plotTop),
          endPoint: CGPoint(x: 0, y: geometry.plotBottom)
        )
      )
    }
  }

  private func drawRPE(
    context: inout GraphicsContext,
    geometry: VolumeChartGeometry
  ) {
    guard let first = geometry.rpePoints.first else { return }
    var line = Path()
    line.move(to: first)
    for point in geometry.rpePoints.dropFirst() {
      line.addLine(to: point)
    }
    context.stroke(
      line,
      with: .color(Color.MeetPR.bgBase),
      style: StrokeStyle(lineWidth: geometry.scaleX(3), lineCap: .round, lineJoin: .round)
    )
    context.stroke(
      line,
      with: .color(Color.MeetPR.chartLine),
      style: StrokeStyle(lineWidth: geometry.scaleX(1.2), lineCap: .round, lineJoin: .round)
    )
    let radius = geometry.scaleX(2.6)
    for point in geometry.rpePoints {
      let dot = Path(
        ellipseIn: CGRect(
          x: point.x - radius,
          y: point.y - radius,
          width: radius * 2,
          height: radius * 2
        )
      )
      context.fill(dot, with: .color(Color.MeetPR.chartLine))
      context.stroke(
        dot,
        with: .color(Color.MeetPR.bgBase),
        lineWidth: geometry.scaleX(1.2)
      )
    }
  }

  private func labels(_ geometry: VolumeChartGeometry) -> some View {
    ZStack {
      volumeLabel(geometry.volumeTopLabel)
        .position(geometry.point(x: 30, y: 21))
      volumeLabel(geometry.volumeMiddleLabel)
        .position(geometry.point(x: 30, y: 85))
      volumeLabel("0")
        .position(geometry.point(x: 30, y: 149))
      rpeLabel("10")
        .position(geometry.point(x: 309, y: 21))
      rpeLabel("7.5")
        .position(geometry.point(x: 309, y: 58))
      rpeLabel("5")
        .position(geometry.point(x: 309, y: 95))

      ForEach(geometry.dateLabels.indices, id: \.self) { index in
        let label = geometry.dateLabels[index]
        Text(label.text)
          .font(.MeetPR.mono(size: 8, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
          .position(x: label.x, y: geometry.scaleY(162))
          .opacity(index.isMultiple(of: 2) ? 1 : 0)
      }
    }
  }

  private func volumeLabel(_ text: String) -> some View {
    Text(text)
      .font(.MeetPR.mono(size: 9, weight: .medium))
      .foregroundStyle(Color.MeetPR.textMuted)
  }

  private func rpeLabel(_ text: String) -> some View {
    Text(text)
      .font(.MeetPR.mono(size: 9, weight: .medium))
      .foregroundStyle(Color.MeetPR.chartLine)
  }

  private func legend(title: String, color: Color, isCircle: Bool) -> some View {
    HStack(spacing: MeetPRSpacing.point5) {
      Group {
        if isCircle {
          Circle().fill(color)
        } else {
          RoundedRectangle(cornerRadius: MeetPRRadius.micro).fill(color)
        }
      }
      .frame(width: 9, height: 9)
      Text(title)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
  }

  private var accessibilityLabel: String {
    guard isUnlocked, !buckets.isEmpty else {
      return "完成 3 次训练后解锁趋势"
    }
    return "容量和平均 RPE 趋势图，共 \(buckets.count) 周"
  }
}

private struct VolumeChartGeometry {
  struct DateLabel {
    let text: String
    let x: CGFloat
  }

  let buckets: [WeeklyProgressMetric]
  let size: CGSize
  let volumeMaximum: Double

  init(buckets: [WeeklyProgressMetric], size: CGSize) {
    self.buckets = buckets
    self.size = size
    let maximum =
      buckets
      .map { NSDecimalNumber(decimal: $0.volumeKg).doubleValue }
      .max() ?? 0
    let increment = maximum > 10_000 ? 5_000.0 : (maximum > 2_000 ? 1_000.0 : 500.0)
    self.volumeMaximum = max(increment, ceil(maximum / increment) * increment)
  }

  var bars: [Path] {
    buckets.enumerated().map { index, bucket in
      let center = centerX(index)
      let halfWidth = scaleX(5)
      let radius = scaleX(4)
      let volume = NSDecimalNumber(decimal: bucket.volumeKg).doubleValue
      let top = scaleY(146 - 128 * min(max(volume / volumeMaximum, 0), 1))
      let bottom = scaleY(146)
      var path = Path()
      path.move(to: CGPoint(x: center - halfWidth, y: bottom))
      path.addLine(to: CGPoint(x: center - halfWidth, y: top + radius))
      path.addQuadCurve(
        to: CGPoint(x: center - halfWidth + radius, y: top),
        control: CGPoint(x: center - halfWidth, y: top)
      )
      path.addLine(to: CGPoint(x: center + halfWidth - radius, y: top))
      path.addQuadCurve(
        to: CGPoint(x: center + halfWidth, y: top + radius),
        control: CGPoint(x: center + halfWidth, y: top)
      )
      path.addLine(to: CGPoint(x: center + halfWidth, y: bottom))
      path.closeSubpath()
      return path
    }
  }

  var rpePoints: [CGPoint] {
    buckets.enumerated().compactMap { index, bucket in
      guard let averageRPE = bucket.avgRPE else { return nil }
      let rpe = min(max(averageRPE, 5), 10)
      let y = 92 - (rpe - 5) / 5 * 74
      return CGPoint(x: centerX(index), y: scaleY(y))
    }
  }

  var dateLabels: [DateLabel] {
    buckets.enumerated().map { index, bucket in
      DateLabel(text: Self.dayMonth(bucket.weekStart), x: centerX(index))
    }
  }

  var plotTop: CGFloat { scaleY(18) }
  var plotBottom: CGFloat { scaleY(146) }
  var volumeTopLabel: String { Self.compactVolume(volumeMaximum) }
  var volumeMiddleLabel: String { Self.compactVolume(volumeMaximum / 2) }

  func point(x: Double, y: Double) -> CGPoint {
    CGPoint(x: scaleX(x), y: scaleY(y))
  }

  func scaleX(_ value: Double) -> CGFloat {
    CGFloat(value) / 320 * size.width
  }

  func scaleY(_ value: Double) -> CGFloat {
    CGFloat(value) / 172 * size.height
  }

  private func centerX(_ index: Int) -> CGFloat {
    guard buckets.count > 1 else { return scaleX(168) }
    let first = 58.0
    let last = 278.0
    return scaleX(first + (last - first) * Double(index) / Double(buckets.count - 1))
  }

  private static func compactVolume(_ value: Double) -> String {
    guard value >= 1_000 else {
      return Int(value.rounded()).formatted()
    }
    let thousands = value / 1_000
    if thousands.rounded() == thousands {
      return thousands.formatted(.number.precision(.fractionLength(0))) + "k"
    }
    return thousands.formatted(.number.precision(.fractionLength(1))) + "k"
  }

  private static func dayMonth(_ date: Date) -> String {
    let components = Calendar.current.dateComponents([.day, .month], from: date)
    guard let day = components.day, let month = components.month else { return "—" }
    return "\(day.formatted(.number.precision(.integerLength(2))))/"
      + "\(month.formatted(.number.precision(.integerLength(2))))"
  }
}
