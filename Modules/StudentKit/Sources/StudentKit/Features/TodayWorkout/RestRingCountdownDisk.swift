import DesignSystem
import SwiftUI

struct RestRingCountdownDisk: View {
  let remaining: Int
  let total: Int
  let exercise: String
  let onSettings: () -> Void
  let onAdjust: (Int) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Button(action: onSettings) {
        Image(systemName: "gearshape")
          .font(.system(size: 20))
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel(StudentStrings.localized(.restRingSettings))
      .padding(.top, 14)
      Text(
        StudentStrings.replacing(
          .restRingExerciseRest, values: [exercise, RestRingTime.text(total)])
      )
      .font(.system(size: 12))
      .lineLimit(2)
      .minimumScaleFactor(0.8)
      .multilineTextAlignment(.center)
      .frame(height: 32)
      .padding(.horizontal, 28)
      Text(RestRingTime.text(remaining))
        .font(.system(size: 60, weight: .bold, design: .monospaced))
        .foregroundStyle(remaining <= 10 ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
        .frame(height: 76)
        .minimumScaleFactor(0.8)
      HStack(spacing: 12) {
        RestRingDiskButton(title: StudentStrings.localized(.restRingMinus)) { onAdjust(-15) }
        RestRingDiskButton(
          title: StudentStrings.localized(.restRingEnd), primary: true, action: onEnd)
        RestRingDiskButton(title: StudentStrings.localized(.restRingPlus)) { onAdjust(15) }
      }
      .padding(.top, 10)
      Spacer(minLength: 0)
    }
    .foregroundStyle(Color.MeetPR.textSecondary)
    .frame(width: 280, height: 280)
    .background(Color.MeetPR.surface2, in: .circle)
    .overlay { RestRingProgress(remaining: remaining, total: total, width: 8) }
    .accessibilityIdentifier("restRing.countdown")
  }
}

private struct RestRingDiskButton: View {
  let title: String
  var primary = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(primary ? Color.MeetPR.inkOnCTAFill : Color.MeetPR.textPrimary)
        .frame(width: 56, height: 56)
        .background(primary ? Color.MeetPR.holdTrack : Color.MeetPR.surface3, in: .circle)
        .overlay {
          if !primary { Circle().strokeBorder(Color.MeetPR.borderStrong, lineWidth: 1) }
        }
    }
    .buttonStyle(.plain)
  }
}

struct RestRingProgress: View {
  let remaining: Int
  let total: Int
  let width: CGFloat

  var body: some View {
    ZStack {
      Circle().strokeBorder(Color.MeetPR.borderStrong, lineWidth: width)
      Circle().inset(by: width / 2)
        .trim(from: 0, to: min(1, max(0, Double(remaining) / Double(max(1, total)))))
        .stroke(Color.MeetPR.gold500, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .allowsHitTesting(false)
  }
}

enum RestRingTime {
  static func text(_ seconds: Int) -> String {
    Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
  }
}
