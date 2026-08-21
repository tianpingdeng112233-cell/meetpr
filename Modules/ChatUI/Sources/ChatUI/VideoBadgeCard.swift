import DesignSystem
import SwiftUI

enum VideoBadgeLayout {
  static let cardWidthRatio = 0.84
  static let maximumScreenWidth: CGFloat = 360
  static let referenceWidth: CGFloat = 340
  static let bottomMarginRatio = 0.055

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
    VStack(alignment: .leading, spacing: 0) {
      header

      if let exerciseName = presentation.exerciseName {
        Text(exerciseName)
          .font(.MeetPR.body(size: 18 * scale, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .padding(.top, 14 * scale)
      }

      if presentation.hasLoad || presentation.rpeText != nil {
        metrics
          .padding(.top, 7 * scale)
      }

      if includesCoachAttribution, let coachName = presentation.coachName {
        Text(ChatStrings.videoBadgeCoach(coachName))
          .font(.MeetPR.body(size: 10 * scale, weight: .medium))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .lineLimit(1)
          .padding(.top, 10 * scale)
      }
    }
    .padding(.horizontal, 18 * scale)
    .padding(.vertical, 16 * scale)
    .frame(width: width, alignment: .leading)
    .background(Color.MeetPR.bgInset.opacity(0.97))
    .clipShape(.rect(cornerRadius: 22 * scale))
    .overlay {
      RoundedRectangle(cornerRadius: 22 * scale)
        .stroke(Color.MeetPR.borderStrong.opacity(0.72), lineWidth: max(1, scale))
    }
    .shadow(color: .black.opacity(0.38), radius: 18 * scale, y: 8 * scale)
  }

  private var header: some View {
    HStack(spacing: 8 * scale) {
      VideoBadgeLogoMark(size: 24 * scale)
      Text("MEETPR")
        .font(.MeetPR.display(size: 13 * scale, weight: .black))
        .tracking(0.7 * scale)
        .foregroundStyle(Color.MeetPR.textPrimary)

      Spacer(minLength: 8 * scale)

      if let setOrdinal = presentation.setOrdinal {
        HStack(spacing: 2 * scale) {
          Text(ChatStrings.videoBadgeSetPrefix)
            .foregroundStyle(Color.MeetPR.textTertiary)
          Text(setOrdinal.formatted())
            .bold()
            .foregroundStyle(Color.MeetPR.textPrimary)
          if !ChatStrings.videoBadgeSetSuffix.isEmpty {
            Text(ChatStrings.videoBadgeSetSuffix)
              .foregroundStyle(Color.MeetPR.textTertiary)
          }
        }
        .font(.MeetPR.body(size: 12 * scale))
      }
    }
  }

  private var metrics: some View {
    HStack(alignment: .lastTextBaseline, spacing: 0) {
      if let weightText = presentation.weightText {
        Text(weightText)
          .font(.MeetPR.display(size: 40 * scale, weight: .black))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .monospacedDigit()
        Text("kg")
          .font(.MeetPR.mono(size: 12 * scale, weight: .medium))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.leading, 4 * scale)
      }

      if let reps = presentation.reps {
        Text("×")
          .font(.MeetPR.body(size: 19 * scale, weight: .medium))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .padding(.leading, presentation.weightText == nil ? 0 : 10 * scale)
        Text(reps.formatted())
          .font(.MeetPR.display(size: 29 * scale, weight: .black))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .monospacedDigit()
          .padding(.leading, 4 * scale)
      }

      Spacer(minLength: 8 * scale)

      if let rpeText = presentation.rpeText {
        HStack(alignment: .lastTextBaseline, spacing: 4 * scale) {
          Text("RPE")
            .font(.MeetPR.mono(size: 9 * scale, weight: .medium))
            .foregroundStyle(Color.MeetPR.textTertiary)
          Text(rpeText)
            .font(.MeetPR.mono(size: 15 * scale, weight: .bold))
            .foregroundStyle(Color.MeetPR.gold500)
            .monospacedDigit()
        }
        .padding(.horizontal, 9 * scale)
        .padding(.vertical, 6 * scale)
        .background(Color.MeetPR.surfaceFocus)
        .clipShape(.capsule)
        .overlay {
          Capsule().stroke(Color.MeetPR.gold500, lineWidth: max(1, scale))
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeLogoMark: View {
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Color.MeetPR.gold500)
      VideoBadgeTrendShape()
        .stroke(
          Color.MeetPR.inkOnGold,
          style: StrokeStyle(
            lineWidth: size * 0.105,
            lineCap: .round,
            lineJoin: .round
          )
        )
        .padding(size * 0.23)
      Circle()
        .fill(Color.MeetPR.inkOnGold)
        .frame(width: size * 0.14, height: size * 0.14)
        .offset(x: size * 0.19, y: -size * 0.18)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct VideoBadgeTrendShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.68))
    path.addLine(to: CGPoint(x: rect.midX * 0.9, y: rect.maxY * 0.68))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    return path
  }
}
