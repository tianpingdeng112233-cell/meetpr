import SwiftUI

#if os(iOS)
  import CoreHaptics
#endif

enum MeetPRRollUpSpec {
  struct Stop: Equatable, Sendable {
    let progress: CGFloat
    let rotation: Double
    let translationFraction: CGFloat
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

  static let collapsedHeight: CGFloat = 48

  static let stops = [
    Stop(progress: 0, rotation: 0, translationFraction: 0, scaleY: 1, opacity: 1),
    Stop(progress: 0.15, rotation: -34, translationFraction: -0.03, scaleY: 0.9, opacity: 1),
    Stop(progress: 0.32, rotation: -7, translationFraction: -0.17, scaleY: 0.72, opacity: 1),
    Stop(progress: 0.5, rotation: -38, translationFraction: -0.31, scaleY: 0.52, opacity: 1),
    Stop(progress: 0.67, rotation: -11, translationFraction: -0.46, scaleY: 0.33, opacity: 1),
    Stop(progress: 0.84, rotation: -44, translationFraction: -0.60, scaleY: 0.16, opacity: 0.9),
    Stop(progress: 1, rotation: -74, translationFraction: -0.72, scaleY: 0, opacity: 0),
  ]

  /// `[8, 60, 8, 60, 10, 60, 14]` milliseconds from the mockup:
  /// pulse, pause, pulse, pause, pulse, pause, pulse.
  static let hapticPulses = [
    HapticPulse(durationMilliseconds: 8, pauseAfterMilliseconds: 60, strength: .light),
    HapticPulse(durationMilliseconds: 8, pauseAfterMilliseconds: 60, strength: .medium),
    HapticPulse(durationMilliseconds: 10, pauseAfterMilliseconds: 60, strength: .medium),
    HapticPulse(durationMilliseconds: 14, pauseAfterMilliseconds: 0, strength: .heavy),
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
      translationFraction: lower.translationFraction
        + ((upper.translationFraction - lower.translationFraction) * localProgress),
      scaleY: lower.scaleY + ((upper.scaleY - lower.scaleY) * localProgress),
      opacity: lower.opacity + ((upper.opacity - lower.opacity) * Double(localProgress))
    )
  }

  static func translation(at progress: CGFloat, cardHeight: CGFloat) -> CGFloat {
    values(at: progress).translationFraction * cardHeight
  }

  static func containerHeight(at progress: CGFloat, expandedHeight: CGFloat) -> CGFloat {
    let clamped = min(max(progress, 0), 1)
    return expandedHeight + ((collapsedHeight - expandedHeight) * clamped)
  }
}

public struct RollUpCollapseModifier: @preconcurrency AnimatableModifier {
  public var progress: CGFloat
  @State private var expandedHeight: CGFloat = 0

  public init(isCollapsed: Bool) {
    progress = isCollapsed ? 1 : 0
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
          Color.clear.preference(key: RollUpHeightPreferenceKey.self, value: proxy.size.height)
        }
      }
      .onPreferenceChange(RollUpHeightPreferenceKey.self) { measuredHeight in
        expandedHeight = max(expandedHeight, measuredHeight)
      }
      .rotation3DEffect(
        .degrees(values.rotation),
        axis: (x: 1, y: 0, z: 0),
        anchor: .top,
        perspective: 1 / 820
      )
      .offset(
        y: MeetPRRollUpSpec.translation(
          at: progress,
          cardHeight: expandedHeight
        )
      )
      .scaleEffect(x: 1, y: values.scaleY, anchor: .top)
      .opacity(values.opacity)
      .frame(
        height: expandedHeight > 0
          ? MeetPRRollUpSpec.containerHeight(at: progress, expandedHeight: expandedHeight)
          : nil,
        alignment: .top
      )
      .clipped()
  }
}

private struct RollUpHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

extension View {
  public func meetPRRollUp(isCollapsed: Bool) -> some View {
    modifier(RollUpDispatchModifier(isCollapsed: isCollapsed))
  }
}

/// Chooses between the full 3D roll and a reduce-motion instant collapse.
private struct RollUpDispatchModifier: ViewModifier {
  let isCollapsed: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    if reduceMotion {
      content
        .frame(
          height: isCollapsed ? MeetPRRollUpSpec.collapsedHeight : nil,
          alignment: .top
        )
        .opacity(isCollapsed ? 0 : 1)
        .clipped()
    } else {
      content
        .modifier(RollUpCollapseModifier(isCollapsed: isCollapsed))
        .modifier(RollUpFeedbackModifier(isCollapsed: isCollapsed))
        .animation(
          .timingCurve(0.36, 0.05, 0.3, 1, duration: MeetPRMotion.durationRollUp),
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
