import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardProfileMetricsView: View {
  let metrics: DashboardProfileMetrics
  var showsCompetitionPlaceholder = false
  var showsBodyWeightPlaceholder = false

  var body: some View {
    HStack(spacing: 11) {
      if let bodyWeightText = metrics.bodyWeightText {
        DashboardWeightCard(bodyWeightText: bodyWeightText)
      } else if showsBodyWeightPlaceholder {
        DashboardWeightPlaceholder()
      }
      if let competition = metrics.competition {
        DashboardCompetitionCard(competition: competition)
      } else if showsCompetitionPlaceholder {
        DashboardCompetitionPlaceholder()
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeightPlaceholder: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        DashboardScaleIcon()
          .stroke(
            Color.MeetPR.textDim,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 13, height: 13)
        Text(StudentStrings.localized(.dashboardProfileMetricsView001))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      }
      .foregroundStyle(Color.MeetPR.textMuted)

      Text(StudentStrings.localized(.dashboardProfileMetricsView009))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size18, weight: .bold))
        .foregroundStyle(Color.MeetPR.textMuted)
        .padding(.top, 3)
      Text(StudentStrings.localized(.dashboardProfileMetricsView010))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .bold))
        .foregroundStyle(Color.MeetPR.gold500)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(StudentStrings.localized(.dashboardProfileMetricsView011))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardWeightCard: View {
  let bodyWeightText: String

  private var value: String {
    bodyWeightText.split(separator: " ").first.map(String.init) ?? bodyWeightText
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        DashboardScaleIcon()
          .stroke(
            Color.MeetPR.inkOnCTAFill,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 13, height: 13)
        Text(StudentStrings.localized(.dashboardProfileMetricsView001))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      }
      .foregroundStyle(Color.MeetPR.textPrimary)

      HStack(alignment: .lastTextBaseline, spacing: 0) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size24, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(" kg")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
    .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      StudentStrings.replacing(.dashboardProfileMetricsView002, values: ["\(bodyWeightText)"]))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardCompetitionCard: View {
  let competition: CompetitionCountdown

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        DashboardFlagIcon()
          .stroke(
            Color.MeetPR.gold500,
            style: StrokeStyle(lineWidth: 2, lineJoin: .round)
          )
          .frame(width: 13, height: 13)
        Text(StudentStrings.localized(.dashboardProfileMetricsView003))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textPrimary)
      }

      HStack(alignment: .center, spacing: 5) {
        DashboardFireIcon()
          .stroke(
            Color.MeetPR.gold500,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 14, height: 16)
        Text(competition.days.formatted())
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size24, weight: .bold))
          .foregroundStyle(Color.MeetPR.goldText)
          .shadow(color: Color.MeetPR.goldRGB.opacity(0.45), radius: 7)
        Text(StudentStrings.localized(.dashboardProfileMetricsView004))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      LinearGradient(
        stops: [
          .init(color: Color.MeetPR.goldRGB.opacity(0.13), location: 0),
          .init(color: Color.MeetPR.surfaceCard, location: 0.62),
          .init(color: Color.MeetPR.surfaceCard, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .clipShape(.rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.MeetPR.goldRGB.opacity(0.3), lineWidth: 1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      StudentStrings.replacing(.dashboardProfileMetricsView005, values: ["\(competition.days)"]))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct DashboardCompetitionPlaceholder: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        DashboardFlagIcon()
          .stroke(
            Color.MeetPR.textDim,
            style: StrokeStyle(lineWidth: 2, lineJoin: .round)
          )
          .frame(width: 13, height: 13)
        Text(StudentStrings.localized(.dashboardProfileMetricsView003))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
      }
      .foregroundStyle(Color.MeetPR.textMuted)

      Text(StudentStrings.localized(.dashboardProfileMetricsView006))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size18, weight: .bold))
        .foregroundStyle(Color.MeetPR.textMuted)
        .padding(.top, 3)
      HStack(spacing: 4) {
        // Reference: standalone 11pt stroked plus glyph before the label.
        Image(systemName: "plus")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11, weight: .bold))
        Text(StudentStrings.localized(.dashboardProfileMetricsView007))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .bold))
      }
      .foregroundStyle(Color.MeetPR.gold500)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(StudentStrings.localized(.dashboardProfileMetricsView008))
    // Design source:
    // docs/design/handoff-v3/empty-states/MeetPR 学员端 空状态 暗色.html
    // scene 04, bottom-right competition tile.
  }
}

private struct DashboardScaleIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let transform = CGAffineTransform(
      scaleX: rect.width / 24,
      y: rect.height / 24
    )
    path.move(to: CGPoint(x: 12, y: 3))
    path.addLine(to: CGPoint(x: 12, y: 9))
    path.move(to: CGPoint(x: 7, y: 21))
    path.addLine(to: CGPoint(x: 17, y: 21))
    path.addCurve(
      to: CGPoint(x: 19, y: 19),
      control1: CGPoint(x: 18.1, y: 21),
      control2: CGPoint(x: 19, y: 20.1)
    )
    path.addCurve(
      to: CGPoint(x: 5, y: 19),
      control1: CGPoint(x: 19, y: 9.7),
      control2: CGPoint(x: 5, y: 9.7)
    )
    path.addCurve(
      to: CGPoint(x: 7, y: 21),
      control1: CGPoint(x: 5, y: 20.1),
      control2: CGPoint(x: 5.9, y: 21)
    )
    return path.applying(transform)
  }
}

private struct DashboardFlagIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let transform = CGAffineTransform(
      scaleX: rect.width / 24,
      y: rect.height / 24
    )
    path.move(to: CGPoint(x: 5, y: 21))
    path.addLine(to: CGPoint(x: 5, y: 4))
    path.addLine(to: CGPoint(x: 16, y: 4))
    path.addLine(to: CGPoint(x: 14, y: 8))
    path.addLine(to: CGPoint(x: 16, y: 12))
    path.addLine(to: CGPoint(x: 5, y: 12))
    return path.applying(transform)
  }
}

private struct DashboardFireIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let transform = CGAffineTransform(
      scaleX: rect.width / 24,
      y: rect.height / 24
    )
    path.move(to: CGPoint(x: 8.5, y: 14.5))
    path.addCurve(
      to: CGPoint(x: 11, y: 12),
      control1: CGPoint(x: 9.88, y: 14.5),
      control2: CGPoint(x: 11, y: 13.38)
    )
    path.addCurve(
      to: CGPoint(x: 10, y: 9),
      control1: CGPoint(x: 11, y: 10.62),
      control2: CGPoint(x: 10.5, y: 10)
    )
    path.addCurve(
      to: CGPoint(x: 12, y: 3),
      control1: CGPoint(x: 8.93, y: 6.86),
      control2: CGPoint(x: 9.78, y: 4.95)
    )
    path.addCurve(
      to: CGPoint(x: 16, y: 9.5),
      control1: CGPoint(x: 12.5, y: 5.5),
      control2: CGPoint(x: 14, y: 7.9)
    )
    path.addCurve(
      to: CGPoint(x: 19, y: 15),
      control1: CGPoint(x: 18, y: 11.1),
      control2: CGPoint(x: 19, y: 13)
    )
    path.addArc(
      center: CGPoint(x: 12, y: 15),
      radius: 7,
      startAngle: .degrees(0),
      endAngle: .degrees(180),
      clockwise: false
    )
    path.addCurve(
      to: CGPoint(x: 6, y: 12),
      control1: CGPoint(x: 5, y: 13.85),
      control2: CGPoint(x: 5.43, y: 12.71)
    )
    path.addCurve(
      to: CGPoint(x: 8.5, y: 14.5),
      control1: CGPoint(x: 6.72, y: 13.58),
      control2: CGPoint(x: 7.54, y: 14.5)
    )
    return path.applying(transform)
  }
}
