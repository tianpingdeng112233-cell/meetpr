import SwiftUI

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
      VStack(spacing: MeetPRSpacing.zero) {
        if isLoading {
          Rectangle()
            .fill(Color.MeetPR.gold500)
            .frame(height: 1)
        }

        Text(title)
          .font(Font.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textSecondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .padding(.horizontal, MeetPRSpacing.lg)
          .padding(.vertical, MeetPRSpacing.point14)
          .frame(maxWidth: isFullWidth ? .infinity : nil)
          .frame(minHeight: 44)
      }
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.pill)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
    }
    .buttonStyle(PressScaleButtonStyle(isDisabled: isDisabled || isLoading))
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
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("PrimaryButton Light") {
  PrimaryButton("Save Mesocycle") {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
