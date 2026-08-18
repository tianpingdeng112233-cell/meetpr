// Chart drawing helpers intentionally stay with their shared geometry model.
// swiftlint:disable file_length
import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthE1RMCard: View {
  let snapshot: GrowthCurveSnapshot
  let range: GrowthTimeRange
  let isGlobalTrainingEmpty: Bool
  let onOpenToday: () -> Void
  let onCycleRange: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("\(snapshot.family.studentDisplayName) E1RM")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        Button {
          if reduceMotion {
            onCycleRange()
          } else {
            withAnimation(MeetPRMotion.pillSelect) {
              onCycleRange()
            }
          }
        } label: {
          HStack(spacing: MeetPRSpacing.space1) {
            Text(range.displayName)
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
              .foregroundStyle(Color.MeetPR.textSecondary)
            Image(systemName: "chevron.down")
              .font(.system(size: MeetPRFontMetrics.size10, weight: .bold))
              .foregroundStyle(Color.MeetPR.gold500)
          }
          .padding(.leading, MeetPRSpacing.point10)
          .padding(.trailing, MeetPRSpacing.point5)
          .frame(height: MeetPRSpacing.point22)
          .background(Color.MeetPR.surfaceElevated)
          .clipShape(.capsule)
          .overlay {
            Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
          }
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          StudentStrings.replacing(
            .growthE1Rmcard001,
            values: ["\(snapshot.family.studentDisplayName)", "\(range.displayName)"]
          )
        )
        .accessibilityHint(StudentStrings.localized(.growthE1Rmcard002))
      }
      .frame(height: MeetPRSpacing.minimumHitTarget)
      .padding(.top, -MeetPRSpacing.point9)

      HStack(alignment: .lastTextBaseline) {
        HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space1) {
          Text(weightText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size38, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text("kg")
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size15, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        Spacer()
        if snapshot.cardState == .formingProgress {
          Text(StudentStrings.localized(.growthE1Rmcard003))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textMuted)
        } else if snapshot.cardState == .chart, let deltaText {
          Text(deltaText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13, weight: .bold))
            .foregroundStyle(Color.MeetPR.goldText)
        }
      }

      switch snapshot.cardState {
      case .zero:
        GrowthZeroTrainingState(
          showsAction: isGlobalTrainingEmpty && snapshot.family == .squat,
          onOpenToday: onOpenToday
        )
        .frame(height: 228)
      case .formingProgress:
        GrowthFormingTrendState(
          recordedCount: snapshot.eligibleDataPointCount,
          threshold: GrowthHistoryStats.trendUnlockThreshold,
          familyName: snapshot.family.studentDisplayName,
          currentKg: snapshot.currentKg,
          latestRecordDate: snapshot.latestRecordDate
        )
        .frame(height: 126)
      case .formingWindowSparse:
        GrowthWindowSparseTrendState(
          message: GrowthE1RMCardCopy.windowSparseMessage(window: range.displayName)
        )
        .frame(height: 126)
      case .chart:
        GrowthE1RMChart(snapshot: snapshot)
          .aspectRatio(320 / 118, contentMode: .fit)
          .padding(.top, MeetPRSpacing.space2)
      }
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .accessibilityElement(children: .contain)
  }

  private var weightText: String {
    guard let value = snapshot.currentKg else {
      return snapshot.cardState == .zero ? StudentStrings.localized(.growthE1Rmcard004) : "—"
    }
    return value.formatted(.number.precision(.fractionLength(1)))
  }

  private var deltaText: String? {
    guard let delta = snapshot.deltaKg else { return nil }
    let sign = delta >= 0 ? "+" : "−"
    return sign + abs(delta).formatted(.number.precision(.fractionLength(1)))
  }

}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthE1RMChart: View {
  let snapshot: GrowthCurveSnapshot

  var body: some View {
    GeometryReader { proxy in
      let geometry = GrowthChartGeometry(snapshot: snapshot, size: proxy.size)
      ZStack {
        Canvas { context, _ in
          drawGrid(context: &context, geometry: geometry)
          drawAreaAndLine(context: &context, geometry: geometry)
          drawRawEligible(context: &context, geometry: geometry)
          drawCurrentPoint(context: &context, geometry: geometry)
        }
        chartLabels(geometry)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      StudentStrings.replacing(
        .growthE1Rmcard005,
        values: ["\(snapshot.family.studentDisplayName)", "\(snapshot.windowDataPointCount)"])
    )
  }

  private func drawGrid(
    context: inout GraphicsContext,
    geometry: GrowthChartGeometry
  ) {
    var axes = Path()
    axes.move(to: geometry.point(x: 46, y: 18))
    axes.addLine(to: geometry.point(x: 46, y: 84))
    axes.addLine(to: geometry.point(x: 304, y: 84))
    context.stroke(axes, with: .color(Color.MeetPR.textGhost), lineWidth: 1)

    var middle = Path()
    middle.move(to: geometry.point(x: 46, y: 51))
    middle.addLine(to: geometry.point(x: 304, y: 51))
    context.stroke(
      middle,
      with: .color(Color.MeetPR.borderSubtle),
      style: StrokeStyle(lineWidth: 1, dash: [3, 4])
    )
  }

  private func drawAreaAndLine(
    context: inout GraphicsContext,
    geometry: GrowthChartGeometry
  ) {
    guard let first = geometry.plotPoints.first, let last = geometry.plotPoints.last else {
      return
    }
    var area = Path()
    area.move(to: first)
    for point in geometry.plotPoints.dropFirst() {
      area.addLine(to: point)
    }
    area.addLine(to: CGPoint(x: last.x, y: geometry.plotBottom))
    area.addLine(to: CGPoint(x: first.x, y: geometry.plotBottom))
    area.closeSubpath()
    context.fill(
      area,
      with: .linearGradient(
        Gradient(stops: [
          .init(color: Color.MeetPR.gold500.opacity(0.22), location: 0),
          .init(color: Color.MeetPR.gold500.opacity(0.04), location: 0.72),
          .init(color: Color.MeetPR.gold500.opacity(0), location: 1),
        ]),
        startPoint: CGPoint(x: 0, y: geometry.plotTop),
        endPoint: CGPoint(x: 0, y: geometry.plotBottom)
      )
    )

    var line = Path()
    line.move(to: first)
    for point in geometry.plotPoints.dropFirst() {
      line.addLine(to: point)
    }
    context.stroke(
      line,
      with: .color(Color.MeetPR.chartLine),
      style: StrokeStyle(lineWidth: geometry.scaleX(2.5), lineCap: .round, lineJoin: .round)
    )
  }

  private func drawRawEligible(
    context: inout GraphicsContext,
    geometry: GrowthChartGeometry
  ) {
    for point in geometry.rawEligiblePlotPoints {
      let radius = geometry.scaleX(3)
      var diamond = Path()
      diamond.move(to: CGPoint(x: point.position.x, y: point.position.y - radius))
      diamond.addLine(to: CGPoint(x: point.position.x + radius, y: point.position.y))
      diamond.addLine(to: CGPoint(x: point.position.x, y: point.position.y + radius))
      diamond.addLine(to: CGPoint(x: point.position.x - radius, y: point.position.y))
      diamond.closeSubpath()
      // E1RMChart precedent: imported dims textTertiary, logged dims the
      // theme-aware chart line — literal white vanishes on the light card.
      let color =
        point.origin == .imported
        ? Color.MeetPR.textTertiary.opacity(0.35)
        : Color.MeetPR.chartLine.opacity(0.35)
      context.fill(diamond, with: .color(color))
    }
  }

  private func drawCurrentPoint(
    context: inout GraphicsContext,
    geometry: GrowthChartGeometry
  ) {
    guard let currentPoint = geometry.currentPlotPoint else { return }
    var guide = Path()
    guide.move(to: currentPoint)
    guide.addLine(to: CGPoint(x: currentPoint.x, y: geometry.plotBottom))
    context.stroke(
      guide,
      with: .color(Color.MeetPR.gold500.opacity(0.6)),
      style: StrokeStyle(lineWidth: 1, dash: [2, 3])
    )
    let radius = geometry.scaleX(4.5)
    let dot = Path(
      ellipseIn: CGRect(
        x: currentPoint.x - radius,
        y: currentPoint.y - radius,
        width: radius * 2,
        height: radius * 2
      )
    )
    context.fill(dot, with: .color(Color.MeetPR.gold500))
    context.stroke(dot, with: .color(Color.MeetPR.surfaceCard), lineWidth: geometry.scaleX(1.5))
  }

  private func chartLabels(_ geometry: GrowthChartGeometry) -> some View {
    ZStack {
      axisText(geometry.topLabel)
        .position(geometry.point(x: 33, y: 20))
      axisText(geometry.middleLabel, color: Color.MeetPR.textDim)
        .position(geometry.point(x: 33, y: 52))
      axisText(geometry.bottomLabel)
        .position(geometry.point(x: 33, y: 86))
      Text(StudentStrings.localized(.growthE1Rmcard006))
        .font(.MeetPR.mono(size: geometry.scaleY(8.5)))
        .foregroundStyle(Color.MeetPR.textMuted)
        .rotationEffect(.degrees(-90))
        .position(geometry.point(x: 13, y: 54))
      Text(StudentStrings.localized(.growthE1Rmcard007))
        .font(.MeetPR.mono(size: geometry.scaleY(8.5)))
        .foregroundStyle(Color.MeetPR.textMuted)
        .position(geometry.point(x: 175, y: 114))
      ZStack {
        dateText(geometry.startDateText)
          .frame(width: geometry.dateAxisWidth, alignment: .leading)
        dateText(geometry.endDateText)
          .frame(width: geometry.dateAxisWidth, alignment: .trailing)
      }
      .position(x: geometry.dateAxisCenterX, y: geometry.point(x: 0, y: 98).y)
      // Mockup `g.xMid = (gpL 46 + gpR 300) / 2 = 173` — the plot-area
      // midpoint, not the center of the 50…304 label frame.
      dateText(geometry.middleDateText)
        .position(geometry.point(x: 173, y: 98))
      if let currentPointLabel = geometry.currentPointLabel {
        Text(currentPointLabel.text)
          .font(.MeetPR.mono(size: geometry.scaleY(10), weight: .bold))
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, geometry.scaleX(2))
          .background(Color.MeetPR.surfaceCard.opacity(0.9))
          .position(currentPointLabel.position)
      }
    }
  }

  private func axisText(_ value: String, color: Color = Color.MeetPR.textTertiary) -> some View {
    Text(value)
      .font(.MeetPR.mono(size: 9, weight: .medium))
      .foregroundStyle(color)
  }

  private func dateText(_ value: String) -> some View {
    Text(value)
      .font(.MeetPR.mono(size: 9))
      .foregroundStyle(Color.MeetPR.textMuted)
  }
}

private struct GrowthChartGeometry {
  let samples: [E1RMSeries.Sample]
  let rawEligiblePoints: [E1RMHistoryPoint]
  let chartCurrentPoint: E1RMHistoryPoint?
  let dateAxis: GrowthChartDateAxis
  let size: CGSize
  let lowValue: Double
  let highValue: Double

  init(snapshot: GrowthCurveSnapshot, size: CGSize) {
    self.samples = snapshot.samples
    self.rawEligiblePoints = snapshot.rawEligiblePoints
    self.chartCurrentPoint = snapshot.chartCurrentPoint
    self.dateAxis = GrowthChartDateAxis(snapshot: snapshot)
    self.size = size
    let values = snapshot.samples.map(\.valueKg) + snapshot.rawEligiblePoints.map(\.e1RMKg)
    let minimum = values.min() ?? 0
    let maximum = values.max() ?? minimum
    let span = max(maximum - minimum, 1)
    self.lowValue = minimum - span * 0.35 - 1
    self.highValue = maximum + span * 0.12 + 1
  }

  var plotPoints: [CGPoint] {
    samples.map { sample in
      plotPoint(date: sample.date, valueKg: sample.valueKg)
    }
  }

  var rawEligiblePlotPoints: [(position: CGPoint, origin: E1RMPointOrigin)] {
    rawEligiblePoints.map { point in
      (
        position: plotPoint(date: point.computedAt, valueKg: point.e1RMKg),
        origin: point.origin
      )
    }
  }

  var currentPlotPoint: CGPoint? {
    chartCurrentPoint.map {
      plotPoint(date: $0.computedAt, valueKg: $0.e1RMKg)
    }
  }

  var plotTop: CGFloat { point(x: 0, y: 20).y }
  var plotBottom: CGFloat { point(x: 0, y: 84).y }
  var topLabel: String { Int(highValue.rounded()).formatted() }
  var middleLabel: String { Int(((highValue + lowValue) / 2).rounded()).formatted() }
  var bottomLabel: String { Int(lowValue.rounded()).formatted() }
  var startDateText: String { Self.monthDay(dateDomain.lowerBound) }
  var middleDateText: String { Self.monthDay(dateAxis.middleDate) }
  var endDateText: String { Self.monthDay(dateDomain.upperBound) }
  var dateAxisWidth: CGFloat { scaleX(304 - 50) }
  var dateAxisCenterX: CGFloat { scaleX((304 + 50) / 2) }
  var currentPointLabel: (text: String, position: CGPoint)? {
    guard let point = currentPlotPoint, let date = dateAxis.currentPointDate else {
      return nil
    }
    let x = min(max(point.x, scaleX(62)), scaleX(286))
    // Mockup 934: byLabel = max(15, by - 8) — the label may float above the
    // plot top (y=20), so a peak-ending curve is never covered by its label.
    let y = max(scaleY(15), point.y - scaleY(8))
    return (Self.monthDay(date), CGPoint(x: x, y: y))
  }

  func point(x: Double, y: Double) -> CGPoint {
    CGPoint(x: scaleX(x), y: scaleY(y))
  }

  func scaleX(_ value: Double) -> CGFloat {
    CGFloat(value) / 320 * size.width
  }

  func scaleY(_ value: Double) -> CGFloat {
    CGFloat(value) / 118 * size.height
  }

  private var dateDomain: ClosedRange<Date> {
    dateAxis.startDate...dateAxis.endDate
  }

  private func plotPoint(date: Date, valueKg: Double) -> CGPoint {
    let duration = max(dateDomain.upperBound.timeIntervalSince(dateDomain.lowerBound), 1)
    let dateOffset = date.timeIntervalSince(dateDomain.lowerBound)
    let xFraction = min(max(dateOffset / duration, 0), 1)
    let x = 46 + (300 - 46) * xFraction
    let normalized = (valueKg - lowValue) / max(highValue - lowValue, 1)
    let y = 84 - (84 - 20) * normalized
    return point(x: x, y: y)
  }

  private static func monthDay(_ date: Date?) -> String {
    guard let date else { return "—" }
    let components = Calendar.current.dateComponents([.month, .day], from: date)
    guard let month = components.month, let day = components.day else { return "—" }
    return "\(month)/\(day)"
  }
}

struct GrowthChartDateAxis: Equatable, Sendable {
  let startDate: Date
  let middleDate: Date
  let endDate: Date
  let currentPointDate: Date?

  init(snapshot: GrowthCurveSnapshot) {
    self.init(
      plotDates: snapshot.samples.map(\.date)
        + snapshot.rawEligiblePoints.map(\.computedAt),
      currentPointDate: snapshot.chartCurrentPoint?.computedAt
    )
  }

  init(plotDates: [Date], currentPointDate: Date?) {
    let fallback = Date(timeIntervalSince1970: 0)
    let first = plotDates.min() ?? fallback
    let last = plotDates.max() ?? fallback.addingTimeInterval(1)
    let end = first == last ? last.addingTimeInterval(1) : last

    self.startDate = first
    self.middleDate = first.addingTimeInterval(end.timeIntervalSince(first) / 2)
    self.endDate = end
    self.currentPointDate = currentPointDate
  }
}

// swiftlint:enable file_length
