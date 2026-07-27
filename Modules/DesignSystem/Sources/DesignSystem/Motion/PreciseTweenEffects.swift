import SwiftUI

/// Replays the reference HTML's mathematical tween rather than approximating
/// `easeOutCubic` with a platform spring.
public struct MeetPRRiseInModifier: ViewModifier {
  private let delay: TimeInterval
  private let duration: TimeInterval
  private let offset: CGFloat
  private let initialScaleY: CGFloat
  private let trigger: Int
  private let playsInitially: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress = 0.0
  @State private var completedTrigger: Int?

  public init(
    delay: TimeInterval,
    duration: TimeInterval = MeetPRMotion.durationRise,
    offset: CGFloat = MeetPRMotion.riseInitialOffset,
    initialScaleY: CGFloat = MeetPRMotion.riseInitialScaleY,
    trigger: Int = 0,
    playsInitially: Bool = true
  ) {
    self.delay = delay
    self.duration = duration
    self.offset = offset
    self.initialScaleY = initialScaleY
    self.trigger = trigger
    self.playsInitially = playsInitially
  }

  public func body(content: Content) -> some View {
    let resolvedProgress =
      reduceMotion || (!playsInitially && trigger == 0)
      ? 1
      : progress
    content
      .modifier(
        MeetPRRiseInEffect(
          progress: resolvedProgress,
          offset: offset,
          initialScaleY: initialScaleY
        )
      )
      .task(id: RiseInTaskIdentity(trigger: trigger, reduceMotion: reduceMotion)) {
        guard completedTrigger != trigger else { return }
        guard !reduceMotion else {
          finishWithoutAnimation()
          completedTrigger = trigger
          return
        }
        guard playsInitially || trigger > 0 else {
          finishWithoutAnimation()
          completedTrigger = trigger
          return
        }
        var resetTransaction = Transaction()
        resetTransaction.animation = nil
        withTransaction(resetTransaction) {
          progress = 0
        }
        // motion/04 lines 31-35: base + i×step, followed by a 500ms
        // linear clock whose displayed value is exact easeOutCubic.
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(.linear(duration: duration)) {
          progress = 1
        }
        completedTrigger = trigger
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

private struct RiseInTaskIdentity: Hashable {
  let trigger: Int
  let reduceMotion: Bool
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
    // motion/04 line 34: e=1-(1-p)^3; y=72*(1-e);
    // scaleY=.88+.12*e; opacity=e.
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

public struct MeetPRLaunchMorphOverlay: View {
  private let source: CGRect
  private let destination: CGRect
  private let rootOrigin: CGPoint
  private let progress: Double
  private let fadeProgress: Double

  public init(
    source: CGRect,
    destination: CGRect,
    rootOrigin: CGPoint,
    progress: Double,
    fadeProgress: Double
  ) {
    self.source = source
    self.destination = destination
    self.rootOrigin = rootOrigin
    self.progress = progress
    self.fadeProgress = fadeProgress
  }

  public var body: some View {
    Color.MeetPR.surfaceFocus.opacity(0.97)
      .modifier(
        MeetPRLaunchMorphEffect(
          source: source,
          destination: destination,
          rootOrigin: rootOrigin,
          progress: progress,
          fadeProgress: fadeProgress
        )
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}

private struct MeetPRLaunchMorphEffect: @preconcurrency AnimatableModifier {
  let source: CGRect
  let destination: CGRect
  let rootOrigin: CGPoint
  var progress: Double
  var fadeProgress: Double

  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(progress, fadeProgress) }
    set {
      progress = newValue.first
      fadeProgress = newValue.second
    }
  }

  func body(content: Content) -> some View {
    // motion/01 lines 100-104: 420ms, exact easeOutCubic interpolation,
    // including border radius 28→16.
    let state = MeetPRLaunchMorphSpec.state(
      from: source,
      to: destination,
      rawProgress: progress
    )

    content
      .frame(width: state.frame.width, height: state.frame.height)
      .clipShape(.rect(cornerRadius: state.cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: state.cornerRadius)
          .stroke(Color.MeetPR.goldRGB.opacity(0.8), lineWidth: 1)
      }
      // motion/01 line 88: CSS blur 26px maps to SwiftUI radius 13.
      .shadow(color: Color.MeetPR.goldRGB.opacity(0.18), radius: 13)
      .position(
        x: state.frame.midX - rootOrigin.x,
        y: state.frame.midY - rootOrigin.y
      )
      // motion/01 line 110: the settled ghost fades linearly for 200ms.
      .opacity(1 - fadeProgress)
  }
}

struct MeetPRLaunchMorphSpec {
  struct State: Equatable {
    let frame: CGRect
    let cornerRadius: CGFloat
  }

  /// Converts the raw linear animation clock into the exact eased geometry
  /// and radius used by the reference implementation.
  static func state(
    from source: CGRect,
    to destination: CGRect,
    rawProgress: Double
  ) -> State {
    let clamped = min(max(rawProgress, 0), 1)
    let eased = CGFloat(MeetPRMotion.easeOutCubic(clamped))
    let frame = CGRect(
      x: source.minX + ((destination.minX - source.minX) * eased),
      y: source.minY + ((destination.minY - source.minY) * eased),
      width: source.width + ((destination.width - source.width) * eased),
      height: source.height + ((destination.height - source.height) * eased)
    )
    let cornerRadius =
      MeetPRMotion.launchSourceCornerRadius
      + ((MeetPRMotion.launchDestinationCornerRadius - MeetPRMotion.launchSourceCornerRadius)
        * eased)
    return State(frame: frame, cornerRadius: cornerRadius)
  }
}

public struct MeetPRLaunchExitModifier: @preconcurrency AnimatableModifier {
  public var progress: Double

  public init(progress: Double) {
    self.progress = progress
  }

  public var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  public func body(content: Content) -> some View {
    // motion/01 line 92: e=p²; old screen y=26e and opacity=1-e.
    let eased = progress * progress
    content
      .offset(y: MeetPRMotion.launchExitOffset * CGFloat(eased))
      .opacity(1 - eased)
  }
}

extension View {
  public func meetPRRiseIn(
    delay: TimeInterval,
    duration: TimeInterval = MeetPRMotion.durationRise,
    offset: CGFloat = MeetPRMotion.riseInitialOffset,
    initialScaleY: CGFloat = MeetPRMotion.riseInitialScaleY,
    trigger: Int = 0,
    playsInitially: Bool = true
  ) -> some View {
    modifier(
      MeetPRRiseInModifier(
        delay: delay,
        duration: duration,
        offset: offset,
        initialScaleY: initialScaleY,
        trigger: trigger,
        playsInitially: playsInitially
      )
    )
  }
}
