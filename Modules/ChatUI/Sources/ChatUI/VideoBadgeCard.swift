import DesignSystem
import SwiftUI

/// Design source of truth: docs/design/video-badge/badge-01.html (David,
/// 2026-08-21). All numbers below are that 540×960 artboard's values; the
/// card is 468pt wide there, so `scale = width / 468`.
enum VideoBadgeLayout {
  static let cardWidthRatio = 468.0 / 540.0
  static let maximumScreenWidth: CGFloat = 360
  static let referenceWidth: CGFloat = 468
  static let bottomMarginRatio = 76.0 / 960.0
  static let scrimHeightRatio = 0.44

  static func screenCardWidth(containerWidth: CGFloat) -> CGFloat {
    min(maximumScreenWidth, containerWidth * cardWidthRatio)
  }

  static func exportCardWidth(renderWidth: CGFloat) -> CGFloat {
    renderWidth * cardWidthRatio
  }

  static func exportBottomMargin(renderHeight: CGFloat) -> CGFloat {
    renderHeight * bottomMarginRatio
  }
}

/// Exact artboard colors; the badge is a brand element that must look the
/// same on screen and burned into video, so it does not follow the app theme.
enum VideoBadgePalette {
  static let text = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
  static let muted = Color(red: 138 / 255, green: 138 / 255, blue: 144 / 255)
  static let dim = Color(red: 182 / 255, green: 182 / 255, blue: 188 / 255)
  static let gold = Color(red: 1, green: 184 / 255, blue: 0)
  static let amber = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
  static let ink = Color(red: 245 / 255, green: 246 / 255, blue: 248 / 255)
  static let cardFill = Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255).opacity(0.62)
  static let cardStroke = Color.white.opacity(0.10)
  static let scrim = Color(red: 5 / 255, green: 5 / 255, blue: 7 / 255)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeCard: View {
  let presentation: VideoBadgePresentation
  let width: CGFloat
  let includesCoachAttribution: Bool

  private var scale: CGFloat {
    width / VideoBadgeLayout.referenceWidth
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10 * scale) {
      header

      if let exerciseName = presentation.exerciseName {
        Text(exerciseName)
          .font(.MeetPR.body(size: 14 * scale, weight: .bold))
          .tracking(-0.14 * scale)
          .foregroundStyle(VideoBadgePalette.text)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }

      if presentation.hasLoad || presentation.rpeText != nil {
        metrics
      }

      if includesCoachAttribution, let coachName = presentation.coachName {
        Text(ChatStrings.videoBadgeCoach(coachName))
          .font(.MeetPR.mono(size: 10 * scale, weight: .medium))
          .foregroundStyle(VideoBadgePalette.muted)
          .lineLimit(1)
      }
    }
    .padding(.top, 13 * scale)
    .padding(.horizontal, 14 * scale)
    .padding(.bottom, 14 * scale)
    .frame(width: width, alignment: .leading)
    .background(VideoBadgePalette.cardFill)
    .clipShape(.rect(cornerRadius: 14 * scale))
    .overlay {
      RoundedRectangle(cornerRadius: 14 * scale)
        .stroke(VideoBadgePalette.cardStroke, lineWidth: max(1, scale))
    }
  }

  private var header: some View {
    HStack(spacing: 7 * scale) {
      VideoBadgeLogoMark(size: 22 * scale)
      Image("MeetPRWordmark", bundle: .module)
        .resizable()
        .scaledToFit()
        .frame(height: 16 * scale)
        .accessibilityLabel("MEETPR")

      Spacer(minLength: 8 * scale)

      if let setOrdinal = presentation.setOrdinal {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
          Text(ChatStrings.videoBadgeSetPrefix)
            .font(.MeetPR.mono(size: 10 * scale))
            .foregroundStyle(VideoBadgePalette.muted)
          Text(setOrdinal.formatted())
            .font(.MeetPR.display(size: 13 * scale, weight: .extraBold))
            .foregroundStyle(VideoBadgePalette.text)
          if !ChatStrings.videoBadgeSetSuffix.isEmpty {
            Text(ChatStrings.videoBadgeSetSuffix)
              .font(.MeetPR.mono(size: 10 * scale))
              .foregroundStyle(VideoBadgePalette.muted)
          }
        }
      }
    }
  }

  private var metrics: some View {
    HStack(alignment: .bottom, spacing: 9 * scale) {
      if let weightText = presentation.weightText {
        Text(weightText)
          .font(.MeetPR.display(size: 30 * scale, weight: .extraBold))
          .tracking(-0.6 * scale)
          .foregroundStyle(VideoBadgePalette.text)
          .monospacedDigit()
        Text("kg")
          .font(.MeetPR.mono(size: 14 * scale))
          .foregroundStyle(VideoBadgePalette.muted)
          .padding(.bottom, 3 * scale)
      }

      if let reps = presentation.reps {
        Text("× \(reps.formatted())")
          .font(.MeetPR.display(size: 20 * scale, weight: .extraBold))
          .foregroundStyle(VideoBadgePalette.dim)
          .monospacedDigit()
          .padding(.bottom, 1 * scale)
      }

      Spacer(minLength: 8 * scale)

      if let rpeText = presentation.rpeText {
        HStack(alignment: .center, spacing: 5 * scale) {
          Text("RPE")
            .font(.MeetPR.mono(size: 9 * scale))
            .tracking(0.9 * scale)
            .foregroundStyle(VideoBadgePalette.gold)
          Text(rpeText)
            .font(.MeetPR.display(size: 15 * scale, weight: .extraBold))
            .foregroundStyle(VideoBadgePalette.gold)
            .monospacedDigit()
        }
        .padding(.horizontal, 9 * scale)
        .frame(height: 22 * scale)
        .background(VideoBadgePalette.gold.opacity(0.15))
        .clipShape(.capsule)
        .overlay {
          Capsule().stroke(VideoBadgePalette.gold.opacity(0.42), lineWidth: max(1, scale))
        }
      }
    }
  }
}

/// Bottom darkening behind the card so white text reads on bright footage;
/// artboard: 44% of the frame, rgba(5,5,7,.72) → transparent.
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeScrim: View {
  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        LinearGradient(
          colors: [VideoBadgePalette.scrim.opacity(0), VideoBadgePalette.scrim.opacity(0.72)],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: proxy.size.height * VideoBadgeLayout.scrimHeightRatio)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// Brand mark ported from the artboard SVG (100×100 viewBox): amber disc,
/// upper-left orbit arc, check-trend stroke, dot, faint underline.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeLogoMark: View {
  let size: CGFloat

  private var unit: CGFloat { size / 100 }

  var body: some View {
    ZStack {
      Circle()
        .fill(VideoBadgePalette.amber)
        .frame(width: 78 * unit, height: 78 * unit)
      VideoBadgeOrbitArc()
        .stroke(VideoBadgePalette.ink, style: StrokeStyle(lineWidth: 2.6 * unit, lineCap: .round))
      VideoBadgeTrendShape()
        .stroke(
          VideoBadgePalette.ink,
          style: StrokeStyle(lineWidth: 7 * unit, lineCap: .round, lineJoin: .round)
        )
      VideoBadgeUnderline()
        .stroke(
          VideoBadgePalette.ink.opacity(0.42),
          style: StrokeStyle(lineWidth: 6.4 * unit, lineCap: .round)
        )
      Circle()
        .fill(VideoBadgePalette.ink)
        .frame(width: 12.8 * unit, height: 12.8 * unit)
        .position(x: 66 * unit, y: 37 * unit)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct VideoBadgeOrbitArc: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = rect.width / 100
    var path = Path()
    path.addArc(
      center: CGPoint(x: rect.minX + 50 * unit, y: rect.minY + 50 * unit),
      radius: 30 * unit,
      startAngle: .degrees(205),
      endAngle: .degrees(290.1),
      clockwise: false
    )
    return path
  }
}

private struct VideoBadgeTrendShape: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = rect.width / 100
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 31 * unit, y: rect.minY + 60 * unit))
    path.addLine(to: CGPoint(x: rect.minX + 45 * unit, y: rect.minY + 60 * unit))
    path.addLine(to: CGPoint(x: rect.minX + 64 * unit, y: rect.minY + 39 * unit))
    return path
  }
}

private struct VideoBadgeUnderline: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = rect.width / 100
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 46 * unit, y: rect.minY + 60 * unit))
    path.addLine(to: CGPoint(x: rect.minX + 62 * unit, y: rect.minY + 60 * unit))
    return path
  }
}
