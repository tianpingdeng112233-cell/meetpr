import SwiftUI

@MainActor
public struct SecondaryButton: View {
  private let title: String
  private let isDisabled: Bool
  private let isFullWidth: Bool
  private let action: @MainActor () -> Void

  @State private var feedbackTrigger = false

  public init(
    _ title: String,
    isDisabled: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.isDisabled = isDisabled
    self.isFullWidth = isFullWidth
    self.action = action
  }

  public var body: some View {
    Button(action: handleTap) {
      Text(title)
        .font(Font.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, MeetPRSpacing.lg)
        .padding(.vertical, MeetPRSpacing.point14)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(minHeight: 44)
        .background(Color.MeetPR.surfaceCard)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.pill)
            .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
    }
    .buttonStyle(PressScaleButtonStyle(isDisabled: isDisabled))
    .disabled(isDisabled)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(title)
    .accessibilityHint("Activates this secondary action.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    action()
  }
}

#Preview("SecondaryButton") {
  VStack(spacing: MeetPRSpacing.base) {
    SecondaryButton("Discard") {}
    SecondaryButton("Disabled", isDisabled: true) {}
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("SecondaryButton Light") {
  SecondaryButton("Discard") {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
