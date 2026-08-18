import SwiftUI

/// The four-variant action component defined by `GoldCTA.dc.html`.
@MainActor
public struct GoldCTA: View {
  public enum Variant: Equatable, Sendable {
    case primary
    case secondary
    case danger
    case link
  }

  public enum Icon: Equatable, Sendable {
    case none
    case play
    case logout
  }

  let label: String
  let sub: String?
  let variant: Variant
  let icon: Icon
  private let showsShimmer: Bool
  private let isDisabled: Bool
  private let isLoading: Bool
  private let isFullWidth: Bool
  private let action: @MainActor () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var isHeld = false
  @State private var feedbackTrigger = false
  public init(
    _ label: String = DesignSystemStrings.startTraining,
    sub: String? = DesignSystemStrings.squatBenchDeadlift,
    variant: Variant = .primary,
    icon: Icon = .play,
    showsShimmer: Bool = false,
    isDisabled: Bool = false,
    isLoading: Bool = false,
    isFullWidth: Bool = true,
    action: @escaping @MainActor () -> Void
  ) {
    self.label = label
    self.sub = sub
    self.variant = variant
    self.icon = icon
    self.showsShimmer = showsShimmer
    self.isDisabled = isDisabled
    self.isLoading = isLoading
    self.isFullWidth = isFullWidth
    self.action = action
  }

  public var body: some View {
    Button(action: handlePress) {
      labelContent
        .padding(.horizontal, variant == .link ? MeetPRSpacing.space3 : MeetPRSpacing.space6)
        .frame(maxWidth: isFullWidth && variant != .link ? .infinity : nil)
        .frame(minHeight: minimumHeight)
        .background(backgroundColor)
        .overlay {
          if variant == .secondary || variant == .danger {
            RoundedRectangle(cornerRadius: cornerRadius)
              .stroke(borderColor, lineWidth: 1)
          }
        }
        .overlay(alignment: .top) {
          if variant == .primary && colorScheme == .dark {
            Capsule()
              .stroke(Color.MeetPR.ctaTopHighlight.opacity(0.55), lineWidth: 1.5)
              .mask(alignment: .top) {
                Rectangle().frame(height: MeetPRSpacing.point2)
              }
          }
        }
        .overlay(alignment: .bottom) {
          if variant == .primary && colorScheme == .dark {
            Capsule()
              .stroke(Color.MeetPR.ctaBottomShade.opacity(0.25), lineWidth: 2)
              .mask(alignment: .bottom) {
                Rectangle().frame(height: MeetPRSpacing.point3)
              }
          }
        }
        .meetPRShimmer(showsShimmer && variant == .primary && colorScheme == .dark)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay {
          if let spreadRing {
            RoundedRectangle(cornerRadius: cornerRadius)
              .inset(by: -spreadRing.spread / 2)
              .stroke(spreadRing.color, lineWidth: spreadRing.spread)
          }
        }
        .overlay {
          if isHeld && variant == .primary && colorScheme == .dark {
            GoldCTAHeldGlow(
              cornerRadius: cornerRadius,
              layers: MeetPRVisualEffects.ctaMoldHeld(for: colorScheme)
            )
          }
        }
        .shadow(
          color: shadowColor,
          radius: shadowRadius,
          x: outerShadow?.offsetX ?? 0,
          y: outerShadow?.offsetY ?? 0
        )
        // motion/01 line 77: held CTA uses `filter:brightness(1.06)`.
        .brightness(isHeld && variant == .primary ? 0.06 : 0)
    }
    .buttonStyle(
      GoldCTAButtonStyle(isDisabled: isDisabled || isLoading) { pressed in
        isHeld = pressed
      }
    )
    .disabled(isDisabled || isLoading)
    .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
    .accessibilityLabel(label)
    .accessibilityHint(
      isLoading ? DesignSystemStrings.actionInProgress : DesignSystemStrings.performAction
    )
  }

  private var labelContent: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      if icon == .logout && variant != .link {
        LogoutIconShape()
          .stroke(
            foregroundColor,
            style: StrokeStyle(
              lineWidth: GoldCTAContract.logoutStroke,
              lineCap: .round,
              lineJoin: .round
            )
          )
          .frame(
            width: GoldCTAContract.logoutFrame,
            height: GoldCTAContract.logoutFrame
          )
      }

      VStack(spacing: MeetPRSpacing.space1) {
        HStack(spacing: MeetPRSpacing.zero) {
          if icon == .play && variant != .link {
            PlayIconShape()
              .fill(foregroundColor)
              .frame(width: GoldCTAContract.playFrame, height: GoldCTAContract.playFrame)
              .padding(.trailing, GoldCTAContract.playLabelSpacing)
          }

          Text(label)
            .font(labelFont)
            .tracking(labelTracking)

          if variant == .link {
            ChevronIconShape()
              .stroke(
                foregroundColor,
                style: StrokeStyle(
                  lineWidth: GoldCTAContract.chevronStroke,
                  lineCap: .round,
                  lineJoin: .round
                )
              )
              .frame(
                width: GoldCTAContract.chevronFrame,
                height: GoldCTAContract.chevronFrame
              )
              .padding(.leading, GoldCTAContract.chevronLabelSpacing)
          }
        }
        // motion/01 line 78: primary label opacity 1→.6 while held.
        .opacity(isHeld && variant == .primary ? 0.6 : 1)

        if let sub, variant != .link {
          Text(sub)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
            .tracking(0.72)
            // motion/01 line 78: subtitle opacity .72→.45 while held.
            .opacity(isHeld && variant == .primary ? 0.45 : 0.72)
        }
      }
    }
    .foregroundStyle(foregroundColor)
  }

  private var labelFont: Font {
    switch variant {
    case .primary, .secondary:
      .MeetPR.display(size: MeetPRFontMetrics.size16)
    case .danger:
      .MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold)
    case .link:
      .MeetPR.body(size: MeetPRFontMetrics.size13, weight: .medium)
    }
  }

  private var labelTracking: CGFloat {
    switch variant {
    case .primary, .secondary:
      GoldCTAContract.primaryAndSecondaryLabelTracking
    case .danger, .link:
      0
    }
  }

  private var minimumHeight: CGFloat {
    if variant == .link { return MeetPRSpacing.minimumHitTarget }
    return sub == nil ? MeetPRSpacing.point52 : 62
  }

  private var cornerRadius: CGFloat {
    variant == .danger ? MeetPRRadius.card : MeetPRRadius.pill
  }

  private var backgroundColor: Color {
    switch variant {
    case .primary: Color.MeetPR.ctaBackground
    case .secondary, .danger: Color.MeetPR.surfaceCard
    case .link: Color.MeetPR.bgBase.opacity(0)
    }
  }

  private var foregroundColor: Color {
    switch variant {
    case .primary: Color.MeetPR.ctaText
    case .secondary: Color.MeetPR.textSecondary
    case .danger: Color.MeetPR.dangerMuted
    case .link: Color.MeetPR.textMuted
    }
  }

  private var borderColor: Color {
    variant == .danger ? Color.MeetPR.borderStrong : Color.MeetPR.borderDefault
  }

  private var moldLayers: [MeetPRShadowToken] {
    guard variant == .primary else { return [] }
    return isHeld
      ? MeetPRVisualEffects.ctaMoldHeld(for: colorScheme)
      : MeetPRVisualEffects.ctaMold(for: colorScheme)
  }

  private var spreadRing: MeetPRShadowToken? {
    moldLayers.first(where: { $0.spread > 0 })
  }

  private var outerShadow: MeetPRShadowToken? {
    // motion/01 line 76 has one ring plus two glow layers. During the held
    // state GoldCTAHeldGlow owns both glows; applying `.shadow` here would
    // render the 74/16 layer a second time.
    if isHeld && variant == .primary && colorScheme == .dark { return nil }
    return moldLayers.last(where: { !$0.isInset && $0.blur > 0 })
  }

  private var shadowColor: Color {
    if let outerShadow {
      return outerShadow.color
    }
    return variant == .secondary || variant == .danger
      ? Color.MeetPR.cardShadow
      : Color.MeetPR.cardShadow.opacity(0)
  }

  private var shadowRadius: CGFloat {
    if let outerShadow {
      return outerShadow.swiftUIRadius
    }
    return variant == .secondary || variant == .danger ? 9 : 0
  }

  private func handlePress() {
    feedbackTrigger.toggle()
    action()
  }
}

enum GoldCTAContract {
  static let primaryAndSecondaryLabelTracking: CGFloat = 0.16
  static let playFrame: CGFloat = 13
  static let playLabelSpacing: CGFloat = 7
  static let logoutFrame: CGFloat = 17
  static let logoutStroke: CGFloat = 2
  static let chevronFrame: CGFloat = 13
  static let chevronStroke: CGFloat = 2.2
  static let chevronLabelSpacing: CGFloat = 3
}

private struct PlayIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.point(x: 7, y: 4.5))
    path.addLine(to: rect.point(x: 7, y: 19.5))
    path.addCurve(
      to: rect.point(x: 8.6, y: 20.4),
      control1: rect.point(x: 7, y: 20.3),
      control2: rect.point(x: 7.9, y: 20.8)
    )
    path.addLine(to: rect.point(x: 20.6, y: 12.9))
    path.addCurve(
      to: rect.point(x: 20.6, y: 11.1),
      control1: rect.point(x: 21.2, y: 12.5),
      control2: rect.point(x: 21.2, y: 11.5)
    )
    path.addLine(to: rect.point(x: 8.6, y: 3.6))
    path.addCurve(
      to: rect.point(x: 7, y: 4.5),
      control1: rect.point(x: 7.9, y: 3.2),
      control2: rect.point(x: 7, y: 3.7)
    )
    path.closeSubpath()
    return path
  }
}

private struct LogoutIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.point(x: 9, y: 21))
    path.addLine(to: rect.point(x: 5, y: 21))
    path.addArc(
      tangent1End: rect.point(x: 3, y: 21),
      tangent2End: rect.point(x: 3, y: 19),
      radius: rect.width * 2 / 24
    )
    path.addLine(to: rect.point(x: 3, y: 5))
    path.addArc(
      tangent1End: rect.point(x: 3, y: 3),
      tangent2End: rect.point(x: 5, y: 3),
      radius: rect.width * 2 / 24
    )
    path.addLine(to: rect.point(x: 9, y: 3))
    path.move(to: rect.point(x: 16, y: 17))
    path.addLine(to: rect.point(x: 21, y: 12))
    path.addLine(to: rect.point(x: 16, y: 7))
    path.move(to: rect.point(x: 21, y: 12))
    path.addLine(to: rect.point(x: 9, y: 12))
    return path
  }
}

private struct ChevronIconShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.point(x: 9, y: 6))
    path.addLine(to: rect.point(x: 15, y: 12))
    path.addLine(to: rect.point(x: 9, y: 18))
    return path
  }
}

extension CGRect {
  fileprivate func point(x: CGFloat, y: CGFloat) -> CGPoint {
    CGPoint(
      x: minX + (x / 24) * width,
      y: minY + (y / 24) * height
    )
  }
}

private struct GoldCTAButtonStyle: ButtonStyle {
  let isDisabled: Bool
  let onPressingChanged: (Bool) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !isDisabled && !reduceMotion ? 0.97 : 1)
      .opacity(isDisabled ? 0.35 : 1)
      .animation(reduceMotion ? nil : MeetPRMotion.press, value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _, pressed in
        onPressingChanged(pressed && !isDisabled)
      }
  }
}

#Preview("GoldCTA · All Variants · Dark") {
  VStack(spacing: MeetPRSpacing.point10) {
    GoldCTA {}
    GoldCTA(DesignSystemStrings.shiftOneDay, variant: .link) {}
    GoldCTA(DesignSystemStrings.cancel, sub: nil, variant: .secondary, icon: .none) {}
    GoldCTA(DesignSystemStrings.signOut, sub: nil, variant: .danger, icon: .logout) {}
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("GoldCTA · All Variants · Light") {
  VStack(spacing: MeetPRSpacing.point10) {
    GoldCTA(showsShimmer: true) {}
    GoldCTA(DesignSystemStrings.shiftOneDay, variant: .link) {}
    GoldCTA(DesignSystemStrings.cancel, sub: nil, variant: .secondary, icon: .none) {}
    GoldCTA(DesignSystemStrings.signOut, sub: nil, variant: .danger, icon: .logout) {}
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
