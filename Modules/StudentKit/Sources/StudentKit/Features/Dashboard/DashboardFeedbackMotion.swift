import DesignSystem
import SwiftUI

enum FeedbackHeightTransition {
  static func resolvedStartHeight(
    presentedHeight: CGFloat,
    fallbackHeight: CGFloat
  ) -> CGFloat {
    presentedHeight > 0 ? presentedHeight : fallbackHeight
  }
}

struct FeedbackHeightEffect: @preconcurrency AnimatableModifier {
  var progress: Double
  let startHeight: CGFloat
  let endHeight: CGFloat
  let steadyHeight: CGFloat
  let addsOvershoot: Bool

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    let hasTweenHeights = startHeight > 0 && endHeight > 0
    let eased = MeetPRMotion.feedbackHeightProgress(progress)
    let tweenHeight =
      startHeight
      + ((endHeight - startHeight) * CGFloat(eased))
      + CGFloat(addsOvershoot ? MeetPRMotion.feedbackOvershoot(at: progress) : 0)
    content.frame(
      height: hasTweenHeights ? tweenHeight : (steadyHeight > 0 ? steadyHeight : nil),
      alignment: .top
    )
  }
}

struct FeedbackArrowEffect: @preconcurrency AnimatableModifier {
  var progress: Double

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    // motion/02 line 70: rotation=180*easeOutCubic(p).
    content.rotationEffect(.degrees(180 * MeetPRMotion.easeOutCubic(progress)))
  }
}
