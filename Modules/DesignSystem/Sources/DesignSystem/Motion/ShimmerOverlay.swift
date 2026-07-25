import SwiftUI

public struct ShimmerOverlay: View {
  public init() {}

  public var body: some View {
    TimelineView(.animation) { context in
      GeometryReader { proxy in
        let progress = shimmerProgress(at: context.date)
        let width = proxy.size.width
        LinearGradient(
          colors: [
            .clear,
            Color.MeetPR.shimmerHighlight.opacity(0.42),
            .clear,
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: width * 0.55)
        .rotationEffect(.degrees(-12))
        .offset(x: width * (-1.6 + (5 * progress)))
      }
      .allowsHitTesting(false)
      .clipped()
    }
  }

  private func shimmerProgress(at date: Date) -> Double {
    let elapsed = date.timeIntervalSinceReferenceDate
    let cycle = elapsed.truncatingRemainder(dividingBy: MeetPRMotion.durationShimmer)
    let normalized = cycle / MeetPRMotion.durationShimmer
    guard normalized < 0.3 else { return 1 }
    let travel = normalized / 0.3
    return 0.5 - (cos(.pi * travel) / 2)
  }
}

extension View {
  public func meetPRShimmer(_ isEnabled: Bool = true) -> some View {
    overlay {
      if isEnabled {
        ShimmerOverlay()
      }
    }
  }
}
