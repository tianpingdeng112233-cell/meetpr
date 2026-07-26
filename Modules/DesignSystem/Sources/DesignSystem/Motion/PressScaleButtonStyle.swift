import SwiftUI

public struct PressScaleButtonStyle: ButtonStyle {
  private let isDisabled: Bool
  private let scale: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(isDisabled: Bool = false, scale: CGFloat = 0.97) {
    self.isDisabled = isDisabled
    self.scale = scale
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      // Reduce motion keeps the opacity acknowledgement, drops the transform.
      .scaleEffect(
        configuration.isPressed && !isDisabled && !reduceMotion ? scale : 1
      )
      .opacity(isDisabled ? 0.35 : (configuration.isPressed ? 0.9 : 1))
      .animation(reduceMotion ? nil : MeetPRMotion.press, value: configuration.isPressed)
  }
}
