import SwiftUI

public struct CelebrationEffects: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bloomProgress = 0.0
  @State private var stampProgress = 0.0

  public init() {}

  public var body: some View {
    ZStack {
      CelebrationBloom(progress: bloomProgress)
      CelebrationSparkField()
      CelebrationMedal(progress: stampProgress)
    }
    .frame(width: 220, height: 220)
    .task {
      guard !reduceMotion else {
        bloomProgress = 1
        stampProgress = 1
        return
      }
      withAnimation(.easeOut(duration: MeetPRMotion.durationBloom)) {
        bloomProgress = 1
      }
      withAnimation(.linear(duration: MeetPRMotion.durationStamp)) {
        stampProgress = 1
      }
    }
    .accessibilityHidden(true)
  }
}

private struct CelebrationBloom: View {
  let progress: Double

  var body: some View {
    Circle()
      .fill(
        RadialGradient(
          colors: [
            Color.MeetPR.celebrationBloom.opacity(0.55),
            Color.MeetPR.gold500.opacity(0.16),
            .clear,
          ],
          center: .center,
          startRadius: 0,
          endRadius: 65
        )
      )
      .frame(width: 130, height: 130)
      .scaleEffect(0.2 + (8.5 * progress))
      .opacity(progress < 0.2 ? progress * 4.5 : max(0, 1.125 * (1 - progress)))
  }
}

enum MeetPRCelebrationSpec {
  static let sparkCount = 18

  static func sparkDelay(for index: Int) -> Double {
    Double(index % 6) * MeetPRMotion.sparkStagger
  }
}

private struct CelebrationSparkField: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    if !reduceMotion {
      ZStack {
        ForEach(0..<MeetPRCelebrationSpec.sparkCount, id: \.self) { index in
          CelebrationSpark(index: index)
        }
      }
    }
  }
}

private struct CelebrationSpark: View {
  let index: Int

  @State private var progress = 0.0

  var body: some View {
    let angle =
      (Double(index) / Double(MeetPRCelebrationSpec.sparkCount) * 2 * Double.pi)
      + (Double(index % 3) * 0.35)
    let radius = Double(66 + ((index % 4) * 24))
    let size = CGFloat(3 + (index % 3))
    let fade = progress < 0.7 ? 1 : max(0, 1 - ((progress - 0.7) / 0.3))

    Circle()
      .fill(index % 3 == 0 ? Color.MeetPR.celebrationSpark : .MeetPR.gold500)
      .frame(width: size, height: size)
      .shadow(color: .MeetPR.gold500.opacity(0.85), radius: 7)
      .offset(
        x: cos(angle) * radius * progress,
        y: sin(angle) * radius * progress
      )
      .scaleEffect(1 - (0.8 * progress))
      .opacity(fade)
      .task {
        try? await Task.sleep(
          for: .seconds(MeetPRCelebrationSpec.sparkDelay(for: index))
        )
        withAnimation(.easeOut(duration: MeetPRMotion.durationSpark)) {
          progress = 1
        }
      }
  }
}

private struct CelebrationMedal: View {
  let progress: Double

  var body: some View {
    let scale: Double
    if progress < 0.55 {
      scale = 1.5 - (0.6 * (progress / 0.55))
    } else if progress < 0.78 {
      scale = 0.9 + (0.15 * ((progress - 0.55) / 0.23))
    } else {
      scale = 1.05 - (0.05 * ((progress - 0.78) / 0.22))
    }

    return ZStack {
      MedalRibbons()
      Circle()
        .fill(
          LinearGradient(
            colors: [
              .MeetPR.gold200, .MeetPR.gold500,
              Color.MeetPR.celebrationMedalBottom,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 58, height: 58)
        .overlay {
          Circle()
            .fill(Color.MeetPR.medalInset.opacity(0.92))
            .padding(MeetPRSpacing.point7)
            .overlay {
              Image(systemName: "checkmark")
                .font(
                  .MeetPR.system(
                    size: MeetPRFontMetrics.size28,
                    weight: .bold
                  )
                )
                .foregroundStyle(Color.MeetPR.gold400)
            }
        }
        .offset(y: 20)
    }
    .frame(width: 96, height: 104)
    .scaleEffect(scale)
    .opacity(min(1, progress / 0.4))
    .shadow(color: .MeetPR.gold500.opacity(0.45), radius: 26)
  }
}

private struct MedalRibbons: View {
  var body: some View {
    HStack(spacing: -MeetPRSpacing.point5) {
      Rectangle()
        .fill(
          LinearGradient(
            colors: [.MeetPR.celebrationRibbonStart, .MeetPR.gold800],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .rotationEffect(.degrees(-13))
      Rectangle()
        .fill(
          LinearGradient(
            colors: [.MeetPR.gold700, .MeetPR.gold900],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
          )
        )
        .rotationEffect(.degrees(13))
    }
    .frame(width: 42, height: 56)
    .offset(y: -20)
  }
}
