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
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, MeetPRSpacing.lg)
        .padding(.vertical, 14)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(minHeight: 44)
        .background(.clear)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.lg)
            .stroke(Color.MeetPR.fgPrimary, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: isDisabled))
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
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("SecondaryButton Light") {
  SecondaryButton("Discard") {}
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
