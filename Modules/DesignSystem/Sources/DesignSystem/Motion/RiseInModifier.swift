import SwiftUI

public struct RiseInModifier: ViewModifier {
  private let index: Int
  private let initialDelay: Double
  private let stagger: Double

  @State private var isVisible = false

  public init(
    index: Int,
    initialDelay: Double = MeetPRMotion.riseInitialDelay,
    stagger: Double = MeetPRMotion.riseStagger
  ) {
    self.index = index
    self.initialDelay = initialDelay
    self.stagger = stagger
  }

  public func body(content: Content) -> some View {
    content
      .opacity(isVisible ? 1 : 0)
      .offset(y: isVisible ? 0 : 72)
      .scaleEffect(x: 1, y: isVisible ? 1 : 0.88, anchor: .top)
      .task {
        guard !isVisible else { return }
        let delay = initialDelay + (Double(index) * stagger)
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(MeetPRMotion.rise) {
          isVisible = true
        }
      }
  }
}

public struct PillRiseInModifier: ViewModifier {
  @State private var isVisible = false

  public init() {}

  public func body(content: Content) -> some View {
    content
      .opacity(isVisible ? 1 : 0)
      .offset(y: isVisible ? 0 : -9)
      .scaleEffect(x: 1, y: isVisible ? 1 : 0.62, anchor: .top)
      .task {
        guard !isVisible else { return }
        withAnimation(
          .timingCurve(
            MeetPRMotion.riseX1,
            MeetPRMotion.riseY1,
            MeetPRMotion.riseX2,
            MeetPRMotion.riseY2,
            duration: MeetPRMotion.durationSheet
          )
        ) {
          isVisible = true
        }
      }
  }
}

extension View {
  public func meetPRRiseIn(
    index: Int,
    initialDelay: Double = MeetPRMotion.riseInitialDelay,
    stagger: Double = MeetPRMotion.riseStagger
  ) -> some View {
    modifier(
      RiseInModifier(index: index, initialDelay: initialDelay, stagger: stagger)
    )
  }

  public func meetPRPillRiseIn() -> some View {
    modifier(PillRiseInModifier())
  }
}

extension View {
  /// Gentle opacity pulse for skeleton placeholders; static under reduced
  /// motion (the ghost tone alone still reads as "loading").
  public func meetPRSkeletonPulse() -> some View {
    modifier(SkeletonPulseModifier())
  }
}

private struct SkeletonPulseModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dimmed = false

  func body(content: Content) -> some View {
    content
      .opacity(dimmed ? 0.55 : 1)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
          dimmed = true
        }
      }
  }
}
