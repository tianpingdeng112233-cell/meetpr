import SwiftUI

/// The "in progress" breathing highlight.
///
/// Dark glows: a gold ring plus a gold halo, because the card sits on a near
/// black page and the halo reads as emitted light. Light cannot glow — a gold
/// halo on a white page just looks smudged — so the light mockups redefine the
/// same keyframe as a neutral drop shadow (`0 6px 18px rgba(17,24,39,.22)`) and
/// keep only the ring gold. Both still breathe on the same 4.2s cycle.
public struct GoldGlowModifier: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  private let lineWidth: CGFloat

  public init(lineWidth: CGFloat = 1) {
    self.lineWidth = lineWidth
  }

  public func body(content: Content) -> some View {
    TimelineView(.animation) { context in
      let phase = glowPhase(at: context.date)
      let isLight = colorScheme == .light
      content
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.card)
            .stroke(
              Color.MeetPR.gold500.opacity(0.5 + (0.12 * phase)),
              lineWidth: lineWidth
            )
        }
        .shadow(
          color: isLight
            ? Color.MeetPR.ctaGlow.opacity(0.8 + (0.2 * phase))
            : Color.MeetPR.gold500.opacity(0.24 + (0.08 * phase)),
          radius: isLight ? 9 + (2 * phase) : 8 + (3.5 * phase),
          y: isLight ? 6 : 0
        )
    }
  }

  private func glowPhase(at date: Date) -> Double {
    let elapsed = date.timeIntervalSinceReferenceDate
    let cycle = elapsed.truncatingRemainder(dividingBy: MeetPRMotion.durationGlow)
    return (1 - cos((cycle / MeetPRMotion.durationGlow) * 2 * .pi)) / 2
  }
}

extension View {
  public func meetPRGoldGlow(lineWidth: CGFloat = 1) -> some View {
    modifier(GoldGlowModifier(lineWidth: lineWidth))
  }
}
