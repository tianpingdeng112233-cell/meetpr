import SwiftUI

/// Preserves the reward page's exact mathematical rise tween.
public struct MeetPRRiseInModifier: ViewModifier {
  private let delay: TimeInterval
  private let duration: TimeInterval
  private let offset: CGFloat
  private let initialScaleY: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress = 0.0

  public init(
    delay: TimeInterval,
    duration: TimeInterval,
    offset: CGFloat,
    initialScaleY: CGFloat
  ) {
    self.delay = delay
    self.duration = duration
    self.offset = offset
    self.initialScaleY = initialScaleY
  }

  public func body(content: Content) -> some View {
    content
      .modifier(
        MeetPRRiseInEffect(
          progress: reduceMotion ? 1 : progress,
          offset: offset,
          initialScaleY: initialScaleY
        )
      )
      .task(id: reduceMotion) {
        guard !reduceMotion else {
          finishWithoutAnimation()
          return
        }
        guard progress == 0 else { return }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: duration)) {
          progress = 1
        }
      }
  }

  private func finishWithoutAnimation() {
    var transaction = Transaction()
    transaction.animation = nil
    withTransaction(transaction) {
      progress = 1
    }
  }
}

private struct MeetPRRiseInEffect: @preconcurrency AnimatableModifier {
  var progress: Double
  let offset: CGFloat
  let initialScaleY: CGFloat

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    let eased = MeetPRMotion.easeOutCubic(progress)
    content
      .opacity(eased)
      .offset(y: offset * (1 - eased))
      .scaleEffect(
        x: 1,
        y: initialScaleY + ((1 - initialScaleY) * eased),
        anchor: .center
      )
  }
}

private struct MeetPRCompletionTickerEffect: @preconcurrency AnimatableModifier {
  var progress: Double
  let finalValue: Int

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    let displayed = Int(
      (Double(finalValue) * MeetPRMotion.easeOutQuart(progress)).rounded()
    )
    Text(displayed.formatted(.number.grouping(.automatic)))
  }
}

extension View {
  public func meetPRRiseIn(
    delay: TimeInterval,
    duration: TimeInterval,
    offset: CGFloat,
    initialScaleY: CGFloat
  ) -> some View {
    modifier(
      MeetPRRiseInModifier(
        delay: delay,
        duration: duration,
        offset: offset,
        initialScaleY: initialScaleY
      )
    )
  }

  public func meetPRCompletionTicker(progress: Double, finalValue: Int) -> some View {
    modifier(MeetPRCompletionTickerEffect(progress: progress, finalValue: finalValue))
  }
}
