import SwiftUI

@MainActor
public struct IconButton: View {
  private let systemName: String
  private let accessibilityLabelText: String
  private let isDisabled: Bool
  private let action: @MainActor () -> Void

  @State private var feedbackTrigger = false

  public init(
    systemName: String = "ellipsis",
    accessibilityLabel: String = "More",
    isDisabled: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.systemName = systemName
    self.accessibilityLabelText = accessibilityLabel
    self.isDisabled = isDisabled
    self.action = action
  }

  public var body: some View {
    Button(action: handleTap) {
      Image(systemName: systemName)
        .font(.MeetPR.system(size: MeetPRFontMetrics.size18, weight: .medium))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(width: 44, height: 44)
        .background(Color.MeetPR.surfaceCard)
        .clipShape(.circle)
    }
    .buttonStyle(PressScaleButtonStyle(isDisabled: isDisabled))
    .disabled(isDisabled)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("Opens additional actions.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    action()
  }
}

#Preview("IconButton") {
  HStack(spacing: MeetPRSpacing.base) {
    IconButton {}
    IconButton(systemName: "plus", accessibilityLabel: "Add") {}
    IconButton(isDisabled: true) {}
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("IconButton Light") {
  IconButton {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
