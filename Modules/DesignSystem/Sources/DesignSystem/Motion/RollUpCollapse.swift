import SwiftUI

#if os(iOS)
  import CoreHaptics
#endif

enum MeetPRRollUpSpec {
  struct Stop: Equatable, Sendable {
    let progress: CGFloat
    let rotation: Double
    let scaleY: CGFloat
    let opacity: Double
  }

  enum HapticStrength: Equatable, Sendable {
    case light
    case medium
    case heavy

    var intensity: Float {
      switch self {
      case .light: 0.38
      case .medium: 0.62
      case .heavy: 0.92
      }
    }
  }

  struct HapticPulse: Equatable, Sendable {
    let durationMilliseconds: Int
    let pauseAfterMilliseconds: Int
    let strength: HapticStrength
  }

  /// The mockup measures the real collapsed header and floors it at 44
  /// (`Math.max(44, hdr.offsetHeight)`); this is that floor.
  static let collapsedHeight: CGFloat = 44

  /// `rollUp(i)` WAAPI keyframes, verbatim from the mockup:
  /// offsets 0/.3/.62/1, `rotateX` 0/−26/−52/−78, `scaleY` 1/.82/.48/.06,
  /// opacity 1/.92/.6/0, under `perspective(760px)`.
  static let stops = [
    Stop(progress: 0, rotation: 0, scaleY: 1, opacity: 1),
    Stop(progress: 0.3, rotation: -26, scaleY: 0.82, opacity: 0.92),
    Stop(progress: 0.62, rotation: -52, scaleY: 0.48, opacity: 0.6),
    Stop(progress: 1, rotation: -78, scaleY: 0.06, opacity: 0),
  ]

  /// CSS `perspective(760px)` from the mockup's roll-up keyframes.
  static let perspectiveDistance: CGFloat = 760

  /// `navigator.vibrate([6,50,8,60,12])` from the mockup:
  /// pulse, pause, pulse, pause, pulse.
  static let hapticPulses = [
    HapticPulse(durationMilliseconds: 6, pauseAfterMilliseconds: 50, strength: .light),
    HapticPulse(durationMilliseconds: 8, pauseAfterMilliseconds: 60, strength: .medium),
    HapticPulse(durationMilliseconds: 12, pauseAfterMilliseconds: 0, strength: .heavy),
  ]

  static func values(at progress: CGFloat) -> Stop {
    let clamped = min(max(progress, 0), 1)
    guard let upperIndex = stops.firstIndex(where: { clamped <= $0.progress }) else {
      return stops[stops.count - 1]
    }
    guard upperIndex > 0 else {
      return stops[0]
    }

    let lower = stops[upperIndex - 1]
    let upper = stops[upperIndex]
    let localProgress = (clamped - lower.progress) / (upper.progress - lower.progress)
    return Stop(
      progress: clamped,
      rotation: lower.rotation + ((upper.rotation - lower.rotation) * Double(localProgress)),
      scaleY: lower.scaleY + ((upper.scaleY - lower.scaleY) * localProgress),
      opacity: lower.opacity + ((upper.opacity - lower.opacity) * Double(localProgress))
    )
  }

  /// The mockup measures the real collapsed header and floors it at 44:
  /// `endH = Math.max(44, hdr.offsetHeight)`.
  static func resolvedCollapsedHeight(_ measuredHeader: CGFloat?) -> CGFloat {
    max(collapsedHeight, measuredHeader ?? 0)
  }

  static func containerHeight(
    at progress: CGFloat,
    expandedHeight: CGFloat,
    collapsedHeight measuredHeader: CGFloat? = nil
  ) -> CGFloat {
    let clamped = min(max(progress, 0), 1)
    let endHeight = resolvedCollapsedHeight(measuredHeader)
    return expandedHeight + ((endHeight - expandedHeight) * clamped)
  }
}

public struct RollUpCollapseModifier: @preconcurrency AnimatableModifier {
  public var progress: CGFloat
  private let measuredHeaderHeight: CGFloat?
  @State private var expandedSize: CGSize = .zero

  public init(isCollapsed: Bool, collapsedHeight: CGFloat? = nil) {
    progress = isCollapsed ? 1 : 0
    measuredHeaderHeight = collapsedHeight
  }

  public var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  public func body(content: Content) -> some View {
    let values = MeetPRRollUpSpec.values(at: progress)
    content
      .background {
        GeometryReader { proxy in
          Color.clear.preference(key: RollUpSizePreferenceKey.self, value: proxy.size)
        }
      }
      .onPreferenceChange(RollUpSizePreferenceKey.self) { measuredSize in
        expandedSize = CGSize(
          width: max(expandedSize.width, measuredSize.width),
          height: max(expandedSize.height, measuredSize.height)
        )
      }
      .rotation3DEffect(
        .degrees(values.rotation),
        axis: (x: 1, y: 0, z: 0),
        anchor: .top,
        // CSS `perspective(760px)`: m34 = -1/760 per point. SwiftUI's
        // dimensionless factor divides by the view's width, so scale it back.
        perspective: expandedSize.width > 0
          ? expandedSize.width / MeetPRRollUpSpec.perspectiveDistance
          : 0.47
      )
      .scaleEffect(x: 1, y: values.scaleY, anchor: .top)
      .opacity(values.opacity)
      .frame(
        height: expandedSize.height > 0
          ? MeetPRRollUpSpec.containerHeight(
            at: progress,
            expandedHeight: expandedSize.height,
            collapsedHeight: measuredHeaderHeight
          )
          : nil,
        alignment: .top
      )
      .clipped()
  }
}

private struct RollUpSizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    let next = nextValue()
    value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
  }
}

extension View {
  /// - Parameter collapsedHeight: The measured collapsed-header height; the
  ///   spec floors it at 44 (`Math.max(44, hdr.offsetHeight)` in the mockup).
  public func meetPRRollUp(isCollapsed: Bool, collapsedHeight: CGFloat? = nil) -> some View {
    modifier(RollUpDispatchModifier(isCollapsed: isCollapsed, collapsedHeight: collapsedHeight))
  }
}

/// Chooses between the full 3D roll and a reduce-motion instant collapse.
private struct RollUpDispatchModifier: ViewModifier {
  let isCollapsed: Bool
  let collapsedHeight: CGFloat?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    if reduceMotion {
      content
        .frame(
          height: isCollapsed
            ? MeetPRRollUpSpec.resolvedCollapsedHeight(collapsedHeight)
            : nil,
          alignment: .top
        )
        .opacity(isCollapsed ? 0 : 1)
        .clipped()
    } else {
      content
        .modifier(
          RollUpCollapseModifier(isCollapsed: isCollapsed, collapsedHeight: collapsedHeight)
        )
        .modifier(RollUpFeedbackModifier(isCollapsed: isCollapsed))
        .animation(
          MeetPRMotion.rollUp,
          value: isCollapsed
        )
    }
  }
}

private struct RollUpFeedbackModifier: ViewModifier {
  let isCollapsed: Bool

  @State private var hapticPlayer = RollUpHapticPlayer()

  func body(content: Content) -> some View {
    content
      .task(id: isCollapsed) {
        guard isCollapsed else { return }
        hapticPlayer.play()
      }
  }
}

@MainActor
private final class RollUpHapticPlayer {
  #if os(iOS)
    private var engine: CHHapticEngine?
  #endif

  func play() {
    #if os(iOS)
      guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
      do {
        let activeEngine: CHHapticEngine
        if let engine {
          activeEngine = engine
        } else {
          let newEngine = try CHHapticEngine()
          engine = newEngine
          activeEngine = newEngine
        }
        var relativeTime = 0.0
        let events = MeetPRRollUpSpec.hapticPulses.map { pulse in
          let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
              CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: pulse.strength.intensity
              ),
              CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: min(1, pulse.strength.intensity + 0.08)
              ),
            ],
            relativeTime: relativeTime,
            duration: Double(pulse.durationMilliseconds) / 1_000
          )
          relativeTime +=
            Double(
              pulse.durationMilliseconds + pulse.pauseAfterMilliseconds
            ) / 1_000
          return event
        }
        let pattern = try CHHapticPattern(events: events, parameters: [])
        try activeEngine.start()
        try activeEngine.makePlayer(with: pattern).start(atTime: 0)
      } catch {
        // Haptics are enhancement-only; visual collapse must never be blocked.
      }
    #endif
  }
}
