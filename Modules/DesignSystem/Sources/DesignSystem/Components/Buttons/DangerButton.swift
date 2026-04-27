import SwiftUI

@MainActor
public struct DangerButton: View {
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
        .foregroundStyle(.white)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, MeetPRSpacing.lg)
        .padding(.vertical, 14)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(minHeight: 44)
        .background(Color.MeetPR.brandRed)
        .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
    }
    .buttonStyle(MeetPRPressOpacityButtonStyle(isDisabled: isDisabled))
    .disabled(isDisabled)
    .sensoryFeedback(.warning, trigger: feedbackTrigger)
    .accessibilityLabel(title)
    .accessibilityHint("Performs a destructive action.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    action()
  }
}

#Preview("DangerButton") {
  VStack(spacing: MeetPRSpacing.base) {
    DangerButton("Revoke Access") {}
    DangerButton("Disabled", isDisabled: true) {}
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("DangerButton Light") {
  DangerButton("Revoke Access") {}
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
