import SwiftUI

/// The single source for press-feedback numbers (spec 082 §B.1): every button
/// style in the app reads these so the feel cannot drift between components.
public enum MeetPRPressFeedback {
  public static let scale: CGFloat = 0.97
  public static let pressedOpacity = 0.85
  public static let disabledOpacity = 0.35
}

public struct PressScaleButtonStyle: ButtonStyle {
  private let isDisabled: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled

  public init(isDisabled: Bool = false) {
    self.isDisabled = isDisabled
  }

  public func makeBody(configuration: Configuration) -> some View {
    let disabled = isDisabled || !isEnabled
    configuration.label
      .scaleEffect(
        configuration.isPressed && !disabled && !reduceMotion ? MeetPRPressFeedback.scale : 1
      )
      .opacity(
        disabled
          ? MeetPRPressFeedback.disabledOpacity
          : (configuration.isPressed ? MeetPRPressFeedback.pressedOpacity : 1)
      )
      .animation(nil, value: configuration.isPressed)
  }
}
