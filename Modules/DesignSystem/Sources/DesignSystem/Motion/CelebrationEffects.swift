import SwiftUI

public struct CelebrationEffects: View {
  private let onStamp: @MainActor () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt: Date?
  @State private var didStamp = false

  public init(onStamp: @escaping @MainActor () -> Void = {}) {
    self.onStamp = onStamp
  }

  public var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
      let elapsed = max(0, context.date.timeIntervalSince(startedAt ?? context.date))
      ZStack {
        CelebrationBloom(progress: bloomProgress(elapsed: elapsed))
        if !reduceMotion {
          CelebrationSparkField(elapsed: elapsed)
        }
        CelebrationMedal(progress: reduceMotion ? 1 : stampProgress(elapsed: elapsed))
      }
    }
    .frame(width: 220, height: 220)
    .onAppear {
      // Reduce Motion latches the terminal state: with the clock pinned to
      // the distant past every progress reads 1 and sparks are spent, so
      // toggling Reduce Motion back off cannot replay from mid-flight.
      if reduceMotion {
        startedAt = .distantPast
      } else if startedAt == nil {
        startedAt = Date()
      }
    }
    .onChange(of: reduceMotion) { _, isOn in
      if isOn { startedAt = .distantPast }
    }
    .task(id: reduceMotion) {
      guard !didStamp else { return }
      if !reduceMotion {
        try? await Task.sleep(for: .seconds(MeetPRMotion.durationStamp))
        guard !Task.isCancelled else { return }
      }
      guard !didStamp else { return }
      didStamp = true
      onStamp()
    }
    .accessibilityHidden(true)
  }

  private func bloomProgress(elapsed: TimeInterval) -> Double {
    // motion/05 line 64: bloom uses a 750ms clock.
    guard !reduceMotion else { return 1 }
    return min(1, elapsed / MeetPRMotion.durationBloom)
  }

  private func stampProgress(elapsed: TimeInterval) -> Double {
    min(1, elapsed / MeetPRMotion.durationStamp)
  }
}

private struct CelebrationBloom: View {
  let progress: Double

  var body: some View {
    let eased = MeetPRMotion.easeOutCubic(progress)
    Circle()
      .fill(
        RadialGradient(
          stops: [
            .init(color: Color.MeetPR.celebrationBloom.opacity(0.55), location: 0),
            .init(color: Color.MeetPR.gold500.opacity(0.16), location: 0.55),
            .init(color: .clear, location: 0.74),
          ],
          center: .center,
          startRadius: 0,
          endRadius: 65
        )
      )
      .frame(width: 130, height: 130)
      .scaleEffect(0.2 + (8.5 * eased))
      .opacity(
        progress < 0.2
          ? progress * 4.5
          : max(0, 0.9 * (1 - ((progress - 0.2) / 0.8)))
      )
  }
}

enum MeetPRCelebrationSpec {
  // motion/05 lines 48-54: exactly 18 generated sparks.
  static let sparkCount = 18

  static func sparkDelay(for index: Int) -> Double {
    // motion/05 line 51: `(i % 6) * 18ms`.
    Double(index % 6) * MeetPRMotion.sparkStagger
  }
}

private struct CelebrationSparkField: View {
  let elapsed: TimeInterval

  var body: some View {
    // motion/05 lines 49-54 and 71-74: angle/radius/size/color generation,
    // 800ms easeOutCubic scatter, scale 1→.2 and final-30% fade.
    ZStack {
      ForEach(0..<MeetPRCelebrationSpec.sparkCount, id: \.self) { index in
        CelebrationSpark(index: index, elapsed: elapsed)
      }
    }
  }
}

private struct CelebrationSpark: View {
  let index: Int
  let elapsed: TimeInterval

  var body: some View {
    let angle =
      (Double(index) / Double(MeetPRCelebrationSpec.sparkCount) * 2 * Double.pi)
      + (Double(index % 3) * 0.35)
    let radius = Double(66 + ((index % 4) * 24))
    let size = CGFloat(3 + (index % 3))
    let delayed = elapsed - MeetPRCelebrationSpec.sparkDelay(for: index)
    let progress = min(1, max(0, delayed / MeetPRMotion.durationSpark))
    let eased = MeetPRMotion.easeOutCubic(progress)
    let fade = progress < 0.7 ? 1 : max(0, 1 - ((progress - 0.7) / 0.3))

    Circle()
      .fill(index % 3 == 0 ? Color.MeetPR.celebrationSpark : .MeetPR.gold500)
      .frame(width: size, height: size)
      .shadow(color: .MeetPR.gold500.opacity(0.85), radius: 7)
      .offset(
        x: cos(angle) * radius * eased,
        y: sin(angle) * radius * eased
      )
      .scaleEffect(1 - (0.8 * eased))
      .opacity(delayed < 0 ? 0 : fade)
  }
}

private struct CelebrationMedal: View {
  let progress: Double

  var body: some View {
    CelebrationMedalArtwork()
      .frame(width: 96, height: 104)
      .scaleEffect(scale)
      .opacity(min(1, progress / 0.4))
      .shadow(color: .MeetPR.gold500.opacity(0.45), radius: 26)
  }

  private var scale: Double {
    // motion/05 line 69: 520ms stamp segments 1.5→.9→1.05→1 at .55/.78.
    if progress < 0.55 {
      return 1.5 - (0.6 * (progress / 0.55))
    }
    if progress < 0.78 {
      return 0.9 + (0.15 * ((progress - 0.55) / 0.23))
    }
    return 1.05 - (0.05 * ((progress - 0.78) / 0.22))
  }
}

private struct CelebrationMedalArtwork: View {
  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        CelebrationLeftRibbon()
          .fill(
            LinearGradient(
              colors: [.MeetPR.celebrationRibbonStart, .MeetPR.gold800],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        CelebrationRightRibbon()
          .fill(
            LinearGradient(
              colors: [.MeetPR.gold700, .MeetPR.gold900],
              startPoint: .topTrailing,
              endPoint: .bottomLeading
            )
          )
        Circle()
          .fill(
            LinearGradient(
              stops: [
                .init(color: .MeetPR.gold200, location: 0),
                .init(color: .MeetPR.gold500, location: 0.55),
                .init(color: .MeetPR.celebrationMedalBottom, location: 1),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: size.width * 58 / 96, height: size.height * 58 / 104)
          .position(x: size.width / 2, y: size.height * 72 / 104)
        Circle()
          .fill(Color.MeetPR.medalInset.opacity(0.92))
          .frame(width: size.width * 44 / 96, height: size.height * 44 / 104)
          .position(x: size.width / 2, y: size.height * 72 / 104)
        Circle()
          .stroke(Color.MeetPR.celebrationMedalRing.opacity(0.35), lineWidth: 1)
          .frame(width: size.width * 44 / 96, height: size.height * 44 / 104)
          .position(x: size.width / 2, y: size.height * 72 / 104)
        CelebrationCheckmark()
          .stroke(
            Color.MeetPR.gold400,
            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
          )
      }
    }
  }
}

private struct CelebrationLeftRibbon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.point(x: 27, y: 0, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 44, y: 0, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 53, y: 39, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 38, y: 48, viewBox: CGSize(width: 96, height: 104)))
    path.closeSubpath()
    return path
  }
}

private struct CelebrationRightRibbon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.point(x: 69, y: 0, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 52, y: 0, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 43, y: 39, viewBox: CGSize(width: 96, height: 104)))
    path.addLine(to: rect.point(x: 58, y: 48, viewBox: CGSize(width: 96, height: 104)))
    path.closeSubpath()
    return path
  }
}

private struct CelebrationCheckmark: Shape {
  func path(in rect: CGRect) -> Path {
    let viewBox = CGSize(width: 96, height: 104)
    var path = Path()
    path.move(to: rect.point(x: 37.5, y: 73, viewBox: viewBox))
    path.addLine(to: rect.point(x: 45.5, y: 80.5, viewBox: viewBox))
    path.addLine(to: rect.point(x: 59.5, y: 62, viewBox: viewBox))
    return path
  }
}

extension CGRect {
  fileprivate func point(x: CGFloat, y: CGFloat, viewBox: CGSize) -> CGPoint {
    CGPoint(
      x: minX + (x / viewBox.width * width),
      y: minY + (y / viewBox.height * height)
    )
  }
}
