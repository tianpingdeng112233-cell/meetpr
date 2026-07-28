import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct GrowthTrendEmptyState: View {
  var body: some View {
    Text("完成 3 次训练后解锁趋势")
      .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel("完成三次训练后解锁趋势")
  }
}

/// Design source:
/// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
/// scene 02, e1RM chart dashed slot.
@available(iOS 17.0, macOS 14.0, *)
struct GrowthFormingTrendState: View {
  let recordedCount: Int
  let threshold: Int
  let familyName: String
  let currentKg: Double?
  let latestRecordDate: Date?
  let chartHeight: CGFloat

  init(
    recordedCount: Int,
    threshold: Int,
    familyName: String,
    currentKg: Double?,
    latestRecordDate: Date?,
    chartHeight: CGFloat = 68
  ) {
    self.recordedCount = recordedCount
    self.threshold = threshold
    self.familyName = familyName
    self.currentKg = currentKg
    self.latestRecordDate = latestRecordDate
    self.chartHeight = chartHeight
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      GrowthFormingTrendChart(
        recordedCount: recordedCount,
        threshold: threshold,
        currentKg: currentKg,
        latestRecordDate: latestRecordDate
      )
      .frame(height: chartHeight)

      HStack(spacing: MeetPRSpacing.point9) {
        progressDots
        progressLine
          .lineLimit(2)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, MeetPRSpacing.space3)
      .padding(.vertical, MeetPRSpacing.point9)
      .background(Color.MeetPR.bgInset)
      .clipShape(.rect(cornerRadius: 10))
    }
    .padding(.top, MeetPRSpacing.space2)
    .accessibilityElement(children: .combine)
  }

  private var progressDots: some View {
    HStack(spacing: MeetPRSpacing.space1) {
      ForEach(0..<threshold, id: \.self) { index in
        Circle()
          .fill(index < recordedCount ? Color.MeetPR.gold500 : Color.clear)
          .overlay {
            if index >= recordedCount {
              Circle().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
          }
          .frame(width: 7, height: 7)
      }
    }
  }

  // Reference: base run 12px tertiary; the 1/3 and remaining-count runs are
  // IBM Plex Mono in textPrimary.
  private var progressLine: Text {
    let remaining = max(0, threshold - recordedCount)
    let base: (String) -> Text = { text in
      Text(text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    let mono: (String) -> Text = { text in
      Text(text)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    return base("已记录 ") + mono("\(recordedCount)/\(threshold)")
      + base(" 次——再练 ") + mono("\(remaining)")
      + base(" 次\(familyName)，虚线就变成你的曲线")
  }

}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthFormingTrendChart: View {
  let recordedCount: Int
  let threshold: Int
  let currentKg: Double?
  let latestRecordDate: Date?

  var body: some View {
    Canvas { context, size in
      let points = chartPoints(in: size)
      drawGrid(in: &context, size: size)
      drawGhostCurve(in: &context, points: points)
      drawPoints(in: &context, points: points)
      drawLabels(in: &context, size: size, points: points)
    }
    .accessibilityHidden(true)
  }

  private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
    let plotLeft = size.width * 0.144
    let plotRight = size.width * 0.95
    let plotTop = size.height * 0.1
    let plotMiddle = size.height * 0.43
    let plotBottom = size.height * 0.76

    var axes = Path()
    axes.move(to: CGPoint(x: plotLeft, y: plotTop))
    axes.addLine(to: CGPoint(x: plotLeft, y: plotBottom))
    axes.addLine(to: CGPoint(x: plotRight, y: plotBottom))
    context.stroke(axes, with: .color(Color.MeetPR.borderStrong), lineWidth: 1)

    var middle = Path()
    middle.move(to: CGPoint(x: plotLeft, y: plotMiddle))
    middle.addLine(to: CGPoint(x: plotRight, y: plotMiddle))
    context.stroke(
      middle,
      with: .color(Color.MeetPR.borderSubtle),
      style: StrokeStyle(lineWidth: 1, dash: [3, 4])
    )
  }

  private func drawGhostCurve(
    in context: inout GraphicsContext,
    points: [CGPoint]
  ) {
    guard let first = points.first, let last = points.last else { return }
    var ghost = Path()
    ghost.move(to: first)
    ghost.addCurve(
      to: last,
      control1: CGPoint(
        x: first.x + (last.x - first.x) * 0.3,
        y: first.y - 4
      ),
      control2: CGPoint(
        x: first.x + (last.x - first.x) * 0.68,
        y: last.y + 8
      )
    )
    context.stroke(
      ghost,
      with: .color(Color.MeetPR.borderStrong),
      style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7])
    )
  }

  private func drawPoints(
    in context: inout GraphicsContext,
    points: [CGPoint]
  ) {
    let visibleCount = min(max(0, recordedCount), points.count)
    for (index, point) in points.enumerated() {
      if index < visibleCount {
        let dot = Path(
          ellipseIn: CGRect(
            x: point.x - 4.5,
            y: point.y - 4.5,
            width: 9,
            height: 9
          )
        )
        context.fill(dot, with: .color(Color.MeetPR.gold500))
        context.stroke(dot, with: .color(Color.MeetPR.surfaceCard), lineWidth: 1.5)

        if index == visibleCount - 1 {
          let halo = Path(
            ellipseIn: CGRect(
              x: point.x - 9.5,
              y: point.y - 9.5,
              width: 19,
              height: 19
            )
          )
          context.stroke(
            halo,
            with: .color(Color.MeetPR.goldRGB.opacity(0.35)),
            lineWidth: 1.5
          )
        }
      } else {
        let prediction = Path(
          ellipseIn: CGRect(
            x: point.x - 3.5,
            y: point.y - 3.5,
            width: 7,
            height: 7
          )
        )
        context.stroke(
          prediction,
          with: .color(Color.MeetPR.borderStrong),
          lineWidth: 1.5
        )
      }
    }
  }

  private func drawLabels(
    in context: inout GraphicsContext,
    size: CGSize,
    points: [CGPoint]
  ) {
    // No trusted anchor value → no numeric scale; a fabricated 150-based
    // axis would violate the real-numbers-only rule for low-confidence-only
    // histories.
    if let values = GrowthFormingAxis.labelValues(anchorKg: currentKg) {
      let yPositions = [size.height * 0.1, size.height * 0.43, size.height * 0.76]
      for (index, (value, yPosition)) in zip(values, yPositions).enumerated() {
        // Reference: outer ticks are tertiary, only the middle tick is muted.
        let tickColor =
          index == 1 ? Color.MeetPR.textMuted : Color.MeetPR.textTertiary
        context.draw(
          Text(value.formatted(.number.precision(.fractionLength(0))))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
            .foregroundStyle(tickColor),
          at: CGPoint(x: size.width * 0.115, y: yPosition),
          anchor: .trailing
        )
      }
    }

    let visibleIndex = min(max(0, recordedCount - 1), max(0, points.count - 1))
    guard !points.isEmpty else { return }
    context.draw(
      Text(dateLabel)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size10))
        .foregroundStyle(Color.MeetPR.textMuted),
      at: CGPoint(x: points[visibleIndex].x, y: size.height * 0.91),
      anchor: .center
    )
  }

  private func chartPoints(in size: CGSize) -> [CGPoint] {
    let count = max(1, threshold)
    return (0..<count).map { index in
      let progress = count == 1 ? 0 : CGFloat(index) / CGFloat(count - 1)
      return CGPoint(
        x: size.width * (0.194 + progress * 0.718),
        y: size.height * (0.62 - progress * 0.4)
      )
    }
  }

  private var dateLabel: String {
    guard let latestRecordDate else { return "—" }
    return latestRecordDate.formatted(
      .dateTime
        .day(.twoDigits)
        .month(.twoDigits)
        .locale(Locale(identifier: "en_GB"))
    )
  }
}

/// Design source:
/// `docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html`
/// scene 03, zero-training e1RM-card slot.
@available(iOS 17.0, macOS 14.0, *)
struct GrowthZeroTrainingState: View {
  let showsAction: Bool
  let isCompact: Bool
  let onOpenToday: () -> Void

  init(
    showsAction: Bool,
    isCompact: Bool = false,
    onOpenToday: @escaping () -> Void
  ) {
    self.showsAction = showsAction
    self.isCompact = isCompact
    self.onOpenToday = onOpenToday
  }

  var body: some View {
    VStack(spacing: isCompact ? MeetPRSpacing.point6 : MeetPRSpacing.point10) {
      GrowthZeroGhostChart(size: 64)

      Text(isCompact ? "第一个数据点·等你练出来" : "第一个数据点，等你练出来")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("完成第一次训练后，这里开始记录 e1RM、总量和 PR")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
      if showsAction {
        Button(action: onOpenToday) {
          HStack(spacing: MeetPRSpacing.space2) {
            Text("去看今天的安排")
            Image(systemName: "chevron.right")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size12, weight: .bold))
          }
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
          .foregroundStyle(Color.MeetPR.ctaText)
          .padding(.horizontal, MeetPRSpacing.space5)
          .frame(minHeight: 40)
          .background(Color.MeetPR.ctaBackground, in: .capsule)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct GrowthZeroGhostChart: View {
  let size: CGFloat

  var body: some View {
    Canvas { context, size in
      let circle = Path(
        ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
      )
      context.stroke(
        circle,
        with: .color(Color.MeetPR.borderHairline),
        style: StrokeStyle(lineWidth: 1.5, dash: [3, 6])
      )

      var ghost = Path()
      ghost.move(to: CGPoint(x: size.width * 0.24, y: size.height * 0.64))
      ghost.addCurve(
        to: CGPoint(x: size.width * 0.76, y: size.height * 0.31),
        control1: CGPoint(x: size.width * 0.4, y: size.height * 0.58),
        control2: CGPoint(x: size.width * 0.58, y: size.height * 0.42)
      )
      context.stroke(
        ghost,
        with: .color(Color.MeetPR.borderStrong),
        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 8])
      )

      let point = CGPoint(x: size.width * 0.24, y: size.height * 0.64)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: point.x - 4,
            y: point.y - 4,
            width: 8,
            height: 8
          )
        ),
        with: .color(Color.MeetPR.gold500)
      )
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// Pure axis-label seam for the forming-trend chart: labels exist only when a
/// trusted anchor value does (never fabricate a scale).
enum GrowthFormingAxis {
  static func labelValues(anchorKg: Double?) -> [Double]? {
    guard let anchorKg else { return nil }
    let middleValue = (anchorKg / 10).rounded() * 10
    return [middleValue + 10, middleValue, middleValue - 10]
  }
}
