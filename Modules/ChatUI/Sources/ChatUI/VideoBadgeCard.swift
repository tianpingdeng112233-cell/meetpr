import DesignSystem
import SwiftUI

/// Design source of truth: specs/116-video-badge/SPEC.md (540 × 960 artboard).
struct VideoBadgeLayout {
  let scale: CGFloat

  init(size: CGSize) {
    scale = min(size.width, size.height * 9 / 16) / 540
  }

  /// Distances from the left and bottom edges of the displayed image.
  var exportInsets: CGPoint { CGPoint(x: 44 * scale, y: 214 * scale) }
}

enum VideoBadgePalette {
  static let gold = Color(red: 1, green: 184 / 255, blue: 0)
  static let amber = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)
  static let ink = Color(red: 245 / 255, green: 246 / 255, blue: 248 / 255)
  static let cardFill = Color(red: 12 / 255, green: 12 / 255, blue: 14 / 255).opacity(0.45)
}

struct VideoBadgeCard: View {
  let presentation: VideoBadgePresentation
  let scale: CGFloat

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6 * scale) {
        // The artwork carries its own margin: at 27u the amber disc matches the
        // 21u wordmark. The row keeps its 23u height; the mark overflows by 2u.
        VideoBadgeLogoMark(size: 27 * scale)
          .padding(.vertical, -2 * scale)
        VideoBadgeWordmark.image
          .resizable()
          .frame(width: 21 * scale * 2443 / 605, height: 21 * scale)
          .accessibilityLabel("MEETPR")
        if let ordinal = presentation.setOrdinal {
          Spacer(minLength: 17 * scale)
          Text(ChatStrings.setPosition(ordinal))
            .font(.MeetPR.body(size: 15 * scale, weight: .medium))
            .foregroundStyle(.white.opacity(0.62))
            .fixedSize()
        }
      }

      if let name = presentation.exerciseName {
        Text(name)
          .font(.MeetPR.body(size: 19 * scale, weight: .medium))
          .foregroundStyle(.white.opacity(0.74))
          .lineLimit(1)
          .padding(.top, 12 * scale)
      }

      if presentation.hasLoad || presentation.rpeText != nil {
        VideoBadgeMetrics(presentation: presentation, scale: scale)
          .padding(.top, (presentation.exerciseName == nil ? 12 : 5) * scale)
      }
    }
    .padding(.top, 17 * scale)
    .padding(.horizontal, 22 * scale)
    .padding(.bottom, 19 * scale)
    .frame(maxWidth: 452 * scale, alignment: .leading)
    .fixedSize()
    .background(VideoBadgePalette.cardFill, in: .rect(cornerRadius: 22 * scale))
    .foregroundStyle(.white)
    .environment(\.layoutDirection, .leftToRight)
  }
}

private enum VideoBadgeWordmark {
  static let image: Image = {
    #if os(macOS)
      // Command-line SwiftPM copies the catalog without running actool.
      if let url = Bundle.module.url(
        forResource: "meetpr-wordmark-plain-on-dark", withExtension: "svg",
        subdirectory: "Media.xcassets/MeetPRWordmark.imageset"
      ), let image = NSImage(contentsOf: url) {
        return Image(nsImage: image)
      }
    #endif
    return Image("MeetPRWordmark", bundle: .module)
  }()
}

private struct VideoBadgeMetrics: View {
  let presentation: VideoBadgePresentation
  let scale: CGFloat

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 30 * scale) {
      if presentation.hasLoad {
        HStack(alignment: .firstTextBaseline, spacing: 7 * scale) {
          if let weight = presentation.weightText {
            Text(weight)
              .font(.MeetPR.body(size: 38 * scale, weight: .semibold))
            Text("kg")
              .font(.MeetPR.body(size: 20 * scale, weight: .medium))
              .foregroundStyle(.white.opacity(0.58))
          }
          if let reps = presentation.reps {
            Text("× \(reps.formatted())")
              .font(
                .MeetPR.body(
                  size: (presentation.weightText == nil ? 38 : 29) * scale, weight: .semibold))
          }
        }
      }
      if let rpe = presentation.rpeText {
        HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
          Text("RPE")
            .font(.MeetPR.body(size: 17 * scale, weight: .medium))
            .foregroundStyle(.white.opacity(0.58))
          Text(rpe)
            .font(.MeetPR.body(size: 24 * scale, weight: .semibold))
        }
      }
    }
    .monospacedDigit()
    .lineLimit(1)
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
