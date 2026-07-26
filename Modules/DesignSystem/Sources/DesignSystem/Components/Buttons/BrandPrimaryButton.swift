import SwiftUI

@MainActor
public struct BrandPrimaryButton: View {
  private let title: String
  private let subtitle: String?
  private let systemImage: String?
  private let showsShimmer: Bool
  private let isDisabled: Bool
  private let isLoading: Bool
  private let isFullWidth: Bool
  private let action: @MainActor () -> Void

  @State private var feedbackTrigger = false
  /// Charge-up press state (§3 GoldCTA): dims the label and tightens the glow
  /// while held; release fires the expanding burst below.
  @State private var isCharging = false
  @State private var burstID = 0

  public init(
    _ title: String,
    subtitle: String? = nil,
    systemImage: String? = nil,
    showsShimmer: Bool = false,
    isDisabled: Bool = false,
    isLoading: Bool = false,
    isFullWidth: Bool = false,
    action: @escaping @MainActor () -> Void
  ) {
    self.title = title
    self.subtitle = subtitle
    self.systemImage = systemImage
    self.showsShimmer = showsShimmer
    self.isDisabled = isDisabled
    self.isLoading = isLoading
    self.isFullWidth = isFullWidth
    self.action = action
  }

  public var body: some View {
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
            .foregroundStyle(Color.MeetPR.ctaTextSecondary)
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
          .stroke(Color.MeetPR.ctaTopHighlight.opacity(0.55), lineWidth: 1.5)
          .mask(alignment: .top) {
            Rectangle().frame(height: 2)
          }
      }
      .overlay(alignment: .bottom) {
        Capsule()
          .stroke(Color.MeetPR.ctaBottomShade.opacity(0.25), lineWidth: 2)
          .mask(alignment: .bottom) {
            Rectangle().frame(height: 3)
          }
      }
      .meetPRShimmer(showsShimmer)
      .shadow(
        color: Color.MeetPR.ctaGlow.opacity(isCharging ? 1.0 : 0.82),
        radius: isCharging ? 17 : 13,
        y: 8
      )
      .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
      .opacity(isCharging ? 0.88 : 1)
      .animation(MeetPRMotion.press, value: isCharging)
      .background {
        // Release burst: a gold ring that expands past the screen edge and
        // fades, keyed by burstID so consecutive taps re-fire.
        BurstRing(trigger: burstID)
      }
    }
    .buttonStyle(
      ChargeButtonStyle(isDisabled: isDisabled || isLoading) { pressing in
        isCharging = pressing
      }
    )
    .disabled(isDisabled || isLoading)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(title)
    .accessibilityHint(isLoading ? "Request in progress." : "Activates this action.")
  }

  private func handleTap() {
    feedbackTrigger.toggle()
    burstID += 1
    action()
  }
}

#Preview("BrandPrimaryButton") {
  VStack(spacing: MeetPRSpacing.base) {
    BrandPrimaryButton("Start Training") {}
    BrandPrimaryButton("Loading", isLoading: true) {}
    BrandPrimaryButton("Disabled", isDisabled: true) {}
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("BrandPrimaryButton Light") {
  BrandPrimaryButton("Start Training", isFullWidth: true) {}
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}

/// Press-scale plus a charge callback so the label can dim and the glow can
/// tighten while held.
private struct ChargeButtonStyle: ButtonStyle {
  let isDisabled: Bool
  let onPressingChanged: (Bool) -> Void

  init(isDisabled: Bool, onPressingChanged: @escaping (Bool) -> Void) {
    self.isDisabled = isDisabled
    self.onPressingChanged = onPressingChanged
  }

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !isDisabled ? 0.97 : 1)
      .animation(MeetPRMotion.press, value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _, pressed in
        onPressingChanged(pressed && !isDisabled)
      }
  }
}

/// The expanding gold ring fired on release. Respects reduced motion by
/// simply not drawing.
private struct BurstRing: View {
  let trigger: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var animating = false

  var body: some View {
    Capsule()
      .stroke(Color.MeetPR.gold500.opacity(animating ? 0 : 0.6), lineWidth: 2)
      .scaleEffect(animating ? 6 : 1)
      .opacity(reduceMotion || trigger == 0 ? 0 : 1)
      .allowsHitTesting(false)
      .onChange(of: trigger) { _, _ in
        guard !reduceMotion else { return }
        animating = false
        withAnimation(.easeOut(duration: 0.45)) { animating = true }
      }
  }
}
