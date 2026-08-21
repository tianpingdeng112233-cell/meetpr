import SwiftUI

/// The single gold-gradient progress bar from the handoff header spec:
/// `linear-gradient(90deg, #E08F0F, #FFC93C)`, orange on the left so the bar
/// visibly "heats up" toward completion. 4pt tall, 4pt radius (micro-marker
/// tier), on a stack-colored track.
public struct GoldProgressBar: View {
  private let fraction: Double
  private let height: CGFloat

  public init(fraction: Double, height: CGFloat = 4) {
    self.fraction = fraction.isFinite ? min(max(fraction, 0), 1) : 0
    self.height = height
  }

  public var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.MeetPR.bgStack)
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max(height, geo.size.width * fraction))
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      DesignSystemStrings.weeklyProgress(Int((fraction * 100).rounded()))
    )
  }
}
