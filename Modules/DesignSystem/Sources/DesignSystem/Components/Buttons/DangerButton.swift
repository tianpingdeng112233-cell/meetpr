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
        .font(Font.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.danger)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, MeetPRSpacing.lg)
        .padding(.vertical, MeetPRSpacing.point14)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(minHeight: 44)
        .background(Color.MeetPR.surfaceCard)
        .overlay {
          RoundedRectangle(cornerRadius: MeetPRRadius.card)
            .stroke(Color.MeetPR.danger.opacity(0.4), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    }
    .buttonStyle(PressScaleButtonStyle(isDisabled: isDisabled))
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
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("DangerButton Light") {
  DangerButton("Revoke Access") {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
