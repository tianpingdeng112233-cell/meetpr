import SwiftUI

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// New code must use `GoldCTA`. This implementation preserves the legacy
/// rendering until the coach migration wave while sharing the current press
/// feedback contract.
@MainActor
struct LegacyBrandPrimaryButton: View {
  let title: String
  let subtitle: String?
  let systemImage: String?
  let isDisabled: Bool
  let isLoading: Bool
  let isFullWidth: Bool
  let action: @MainActor () -> Void

  @State private var feedbackTrigger = false
  @State private var isPressedDown = false
  @Environment(\.colorScheme) private var colorScheme

  init(
    _ title: String,
    subtitle: String? = nil,
    systemImage: String? = nil,
    isDisabled: Bool = false,
    isLoading: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.isDisabled = isDisabled
    self.isLoading = isLoading
    self.isFullWidth = isFullWidth
    self.action = action
  }

  var body: some View {
    Button(action: handleTap) {
      VStack(spacing: MeetPRSpacing.space1) {
        if isLoading {
          Rectangle()
            .fill(Color.MeetPR.inkOnGold.opacity(0.35))
            .frame(height: 1)
        }

        Label {
          Text(title)
        } icon: {
          if let systemImage {
            Image(systemName: systemImage)
          }
        }
        .font(Font.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.ctaText)

        if let subtitle {
          Text(subtitle)
            .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
            .tracking(0.72)
            .foregroundStyle(Color.MeetPR.ctaText.opacity(0.72))
        }
      }
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .padding(.horizontal, MeetPRSpacing.space6)
      .padding(.vertical, MeetPRSpacing.point13)
      .frame(maxWidth: isFullWidth ? .infinity : nil)
      .frame(minHeight: 52)
      .background(Color.MeetPR.ctaBackground)
      .overlay(alignment: .top) {
        Capsule()
          .stroke(
            colorScheme == .dark ? Color.MeetPR.ctaTopHighlight.opacity(0.55) : .clear,
            lineWidth: 1.5
          )
          .mask(alignment: .top) {
            Rectangle().frame(height: 2)
          }
      }
      .overlay(alignment: .bottom) {
        Capsule()
          .stroke(
            colorScheme == .dark ? Color.MeetPR.ctaBottomShade.opacity(0.25) : .clear,
            lineWidth: 2
          )
          .mask(alignment: .bottom) {
            Rectangle().frame(height: 3)
          }
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      .overlay {
        if let ring = moldLayers.first(where: { $0.spread > 0 }) {
          Capsule()
            .inset(by: -ring.spread / 2)
            .stroke(ring.color, lineWidth: ring.spread)
        }
      }
      .shadow(
        color: outerShadow?.color ?? .clear,
        radius: outerShadow?.swiftUIRadius ?? 0,
        x: outerShadow?.offsetX ?? 0,
        y: outerShadow?.offsetY ?? 0
      )
    }
    .buttonStyle(
      LegacyPressButtonStyle(isDisabled: isDisabled || isLoading) { pressing in
        isPressedDown = pressing
      }
    )
    .disabled(isDisabled || isLoading)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(title)
    .accessibilityHint(isLoading ? "Request in progress." : "Activates this action.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    action()
  }

  private var moldLayers: [MeetPRShadowToken] {
    isPressedDown
      ? MeetPRVisualEffects.ctaMoldHeld(for: colorScheme)
      : MeetPRVisualEffects.ctaMold(for: colorScheme)
  }

  private var outerShadow: MeetPRShadowToken? {
    moldLayers.last(where: { !$0.isInset && $0.blur > 0 })
  }
}

/// Frozen W0 public entry. New code must use `GoldCTA`.
@MainActor
public struct BrandPrimaryButton: View {
  private let legacy: LegacyBrandPrimaryButton

  public init(
    _ title: String,
    subtitle: String? = nil,
    systemImage: String? = nil,
    isDisabled: Bool = false,
    isLoading: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    legacy = LegacyBrandPrimaryButton(
      title,
      subtitle: subtitle,
      systemImage: systemImage,
      isDisabled: isDisabled,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      action: action
    )
  }

  public var body: some View {
    legacy
  }
}

private struct LegacyPressButtonStyle: ButtonStyle {
  let isDisabled: Bool
  let onPressingChanged: (Bool) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(
        configuration.isPressed && !isDisabled && !reduceMotion ? MeetPRPressFeedback.scale : 1
      )
      .opacity(
        isDisabled
          ? MeetPRPressFeedback.disabledOpacity
          : (configuration.isPressed ? MeetPRPressFeedback.pressedOpacity : 1)
      )
      .animation(nil, value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _, pressed in
        onPressingChanged(pressed && !isDisabled)
      }
  }
}
