import SwiftUI

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// New code must use `GoldCTA(.danger)`. Delete this rendering after the coach
/// migration wave.
@MainActor
struct LegacyDangerButton: View {
  private let title: String
  private let isDisabled: Bool
  private let isFullWidth: Bool
  private let action: @MainActor () -> Void

  @State private var feedbackTrigger = false

  init(
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

  var body: some View {
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

@MainActor
public struct DangerButton: View {
  private let legacy: LegacyDangerButton

  public init(
    _ title: String,
    isDisabled: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    legacy = LegacyDangerButton(
      title,
      isDisabled: isDisabled,
      isFullWidth: isFullWidth,
      action: action
    )
  }

  public var body: some View {
    legacy
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
