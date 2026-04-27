import SwiftUI

struct MeetPRPressOpacityButtonStyle: ButtonStyle {
  let isDisabled: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(isDisabled ? 0.35 : (configuration.isPressed ? 0.6 : 1))
      .animation(MeetPRMotion.easeIOS, value: configuration.isPressed)
  }
}

@MainActor
public struct PrimaryButton: View {
  private let title: String
  private let isDisabled: Bool
  private let isLoading: Bool
  private let isFullWidth: Bool
  private let action: @MainActor () -> Void

  @State private var feedbackTrigger = false

  public init(
    _ title: String,
    isDisabled: Bool = false,
    isLoading: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.isDisabled = isDisabled
    self.isLoading = isLoading
    self.isFullWidth = isFullWidth
    self.action = action
  }

  public var body: some View {
    Button(action: handleTap) {
      VStack(spacing: 0) {
        if isLoading {
          Rectangle()
            .fill(Color.MeetPR.brandRed)
            .frame(height: 1)
        }

        Text(title)
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.bg)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .padding(.horizontal, MeetPRSpacing.lg)
          .padding(.vertical, 14)
          .frame(maxWidth: isFullWidth ? .infinity : nil)
          .frame(minHeight: 44)
      }
      .background(Color.MeetPR.fgPrimary)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: isDisabled || isLoading))
    .disabled(isDisabled || isLoading)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(title)
    .accessibilityHint(isLoading ? "Request in progress." : "Activates this action.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    action()
  }
}

#Preview("PrimaryButton") {
  VStack(spacing: MeetPRSpacing.base) {
    PrimaryButton("Save Mesocycle") {}
    PrimaryButton("Loading", isLoading: true) {}
    PrimaryButton("Disabled", isDisabled: true) {}
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("PrimaryButton Light") {
  PrimaryButton("Save Mesocycle") {}
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
