import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardE1RMRail: View {
  let rows: [DashboardE1RMTrendRow]

  @State private var selectedFamily: LiftFamily?

  var body: some View {
    VStack(spacing: 9) {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 10) {
          ForEach(rows) { row in
            DashboardE1RMCard(row: row)
              .containerRelativeFrame(.horizontal)
              .id(row.family)
          }
        }
        .scrollTargetLayout()
      }
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.paging)
      .scrollPosition(id: $selectedFamily)

      if rows.count > 1 {
        HStack(spacing: 6) {
          ForEach(rows) { row in
            Capsule()
              .fill(
                row.family == effectiveSelectedFamily
                  ? Color.MeetPR.gold500
                  : Color.MeetPR.textGhost
              )
              .frame(
                width: row.family == effectiveSelectedFamily ? 18 : 6,
                height: 6
              )
              .animation(.easeInOut(duration: 0.25), value: effectiveSelectedFamily)
          }
        }
      }
    }
    .onAppear {
      selectedFamily = rows.first?.family
    }
    .onChange(of: rows.map(\.family)) { _, families in
      guard let selectedFamily, families.contains(selectedFamily) else {
        self.selectedFamily = families.first
        return
      }
    }
  }

  private var effectiveSelectedFamily: LiftFamily? {
    selectedFamily ?? rows.first?.family
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardE1RMCard: View {
  let row: DashboardE1RMTrendRow

  private let viewBox = CGSize(width: 320, height: 70)

  private var points: [CGPoint] {
    row.sparklinePoints(width: 312, top: 8, usableHeight: 46)
  }

  private var latestValue: String {
    StudentFormatting.kilograms(row.displayPoint(now: Date())?.e1RMKg ?? 0)
  }

  private var deltaText: String? {
    guard let delta = row.trendDeltaKg else { return nil }
    let sign = delta >= 0 ? "+" : "−"
    return sign + StudentFormatting.kilograms(abs(delta))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Text(row.family.studentDisplayName)
          .foregroundStyle(Color.MeetPR.textSecondary)
          .bold()
        Text("E1RM · \(DashboardE1RMTrendViewModel.chartWindowDays) 天")
      }
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textMuted)

      HStack(alignment: .lastTextBaseline) {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
          Text(latestValue)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size30, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          Text(" kg")
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textMuted)
        }
        Spacer(minLength: 8)
        if let deltaText {
          Text(deltaText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
            .foregroundStyle(Color.MeetPR.goldText)
        }
      }
      .padding(.top, 5)

      ZStack {
        DashboardSparklineArea(points: points, viewBox: viewBox)
        Sparkline(
          points: points,
          viewBox: viewBox,
          lineColor: Color.MeetPR.inkOnCTAFill,
          lineWidth: 2.5,
          showsEndDot: true
        )
      }
      .frame(height: 48)
      .padding(.top, 8)
    }
    .padding(.horizontal, 15)
    .padding(.vertical, 14)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
    .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(row.family.studentDisplayName) E1RM，\(latestValue) 千克"
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardSparklineArea: View {
  let points: [CGPoint]
  let viewBox: CGSize

  var body: some View {
    GeometryReader { proxy in
      let scaleX = proxy.size.width / max(viewBox.width, 1)
      let scaleY = proxy.size.height / max(viewBox.height, 1)
      Path { path in
        guard let first = points.first, let last = points.last else { return }
        path.move(to: CGPoint(x: first.x * scaleX, y: proxy.size.height))
        path.addLine(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
        for point in points.dropFirst() {
          path.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
        }
        path.addLine(to: CGPoint(x: last.x * scaleX, y: proxy.size.height))
        path.closeSubpath()
      }
      .fill(
        LinearGradient(
          stops: [
            .init(color: Color.MeetPR.gold500.opacity(0.28), location: 0),
            .init(color: Color.MeetPR.gold500.opacity(0.06), location: 0.55),
            .init(color: Color.MeetPR.gold500.opacity(0), location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    .accessibilityHidden(true)
  }
}
