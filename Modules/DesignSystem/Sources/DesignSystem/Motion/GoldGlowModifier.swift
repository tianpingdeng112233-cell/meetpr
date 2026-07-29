import SwiftUI

/// The "in progress" breathing highlight — `motion.css` `@keyframes glow`.
///
/// One keyframe set for both themes: a gold ring (`0 0 0 1px` at .5→.62) plus
/// a gold halo (blur 16→23, .24→.32) on a 4.2s cycle. The light theme swaps
/// only `--gold-rgb` (217,119,6), which `goldRGB` already resolves.
public struct GoldGlowModifier: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let lineWidth: CGFloat

  public init(lineWidth: CGFloat = 1) {
    self.lineWidth = lineWidth
  }

  public func body(content: Content) -> some View {
    if reduceMotion {
      staticBody(content: content)
    } else {
      animatedBody(content: content)
    }
  }

  /// Fixed mid-phase ring and shadow — no TimelineView, no breathing.
  private func staticBody(content: Content) -> some View {
    content
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.card)
          .stroke(Color.MeetPR.goldRGB.opacity(0.56), lineWidth: lineWidth)
      }
      .shadow(color: Color.MeetPR.goldRGB.opacity(0.28), radius: 9.75)
  }

  private func animatedBody(content: Content) -> some View {
    TimelineView(.animation) { context in
      let phase = glowPhase(at: context.date)
      content
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.card)
            .stroke(
              Color.MeetPR.goldRGB.opacity(0.5 + (0.12 * phase)),
              lineWidth: lineWidth
            )
        }
        .shadow(
          color: Color.MeetPR.goldRGB.opacity(0.24 + (0.08 * phase)),
          radius: 8 + (3.5 * phase)
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
