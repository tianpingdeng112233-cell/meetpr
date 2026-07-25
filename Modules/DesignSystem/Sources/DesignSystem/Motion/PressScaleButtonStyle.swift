import SwiftUI

public struct PressScaleButtonStyle: ButtonStyle {
  private let isDisabled: Bool
  private let scale: CGFloat

  public init(isDisabled: Bool = false, scale: CGFloat = 0.97) {
    self.isDisabled = isDisabled
    self.scale = scale
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !isDisabled ? scale : 1)
      .opacity(isDisabled ? 0.35 : (configuration.isPressed ? 0.9 : 1))
      .animation(MeetPRMotion.press, value: configuration.isPressed)
  }
}
