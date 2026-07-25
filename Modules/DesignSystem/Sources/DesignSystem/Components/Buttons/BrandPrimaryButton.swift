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
      .shadow(color: Color.MeetPR.ctaGlow, radius: 13, y: 8)
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
