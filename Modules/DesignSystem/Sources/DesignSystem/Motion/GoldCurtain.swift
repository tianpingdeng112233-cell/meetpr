import SwiftUI

/// The "start training" screen transition from handoff §6: a gold energy
/// curtain sweeps up from the bottom, flashes the day label mid-cover, and
/// keeps travelling to reveal the destination underneath. The whole pass runs
/// ~700ms; under reduced motion the curtain never fires and callers switch
/// directly.
public struct MeetPRGoldCurtain: View {
  public enum Phase: Equatable, Sendable {
    case hidden
    /// Sweeping up to cover the screen (280ms) — switch screens once covered.
    case covering
    /// Continuing up and off (420ms), revealing the destination.
    case revealing
  }

  private let phase: Phase
  private let label: String

  public init(phase: Phase, label: String) {
    self.phase = phase
    self.label = label
  }

  public var body: some View {
    GeometryReader { geo in
      ZStack {
        LinearGradient(
          colors: [
            Color.MeetPR.goldGradientStart,
            Color.MeetPR.goldCTA,
            Color.MeetPR.goldGradientEnd,
          ],
          startPoint: .bottom,
          endPoint: .top
        )
        Text(label)
          .font(.MeetPR.display(size: 34, weight: .black))
          .tracking(-0.5)
          .foregroundStyle(Color.MeetPR.inkOnGold)
          .opacity(phase == .covering ? 1 : 0)
          .animation(.easeIn(duration: 0.12), value: phase)
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .offset(y: offsetY(for: geo.size.height))
      .animation(curtainAnimation, value: phase)
    }
    .ignoresSafeArea()
    .allowsHitTesting(phase != .hidden)
    .accessibilityHidden(true)
  }

  private func offsetY(for height: CGFloat) -> CGFloat {
    switch phase {
    case .hidden: height
    case .covering: 0
    case .revealing: -height
    }
  }

  private var curtainAnimation: Animation {
    switch phase {
    case .covering: .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.28)
    case .revealing: .timingCurve(0.2, 0.7, 0.2, 1, duration: 0.42)
    case .hidden: .linear(duration: 0)
    }
  }
}
