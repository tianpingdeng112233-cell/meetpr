import SwiftUI

/// The PrimaryButton appearance for native controls such as ShareLink.
/// Contains no Button, so the native control remains the only tap target.
@MainActor
public struct PrimaryButtonLabel: View {
  private let title: String
  private let systemImage: String?
  private let isLoading: Bool
  private let isFullWidth: Bool

  public init(
    _ title: String, systemImage: String? = nil,
    isLoading: Bool = false, isFullWidth: Bool = false
  ) {
    self.title = title
    self.systemImage = systemImage
    self.isLoading = isLoading
    self.isFullWidth = isFullWidth
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      if isLoading {
        Rectangle()
          .fill(Color.MeetPR.gold500)
          .frame(height: MeetPRSpacing.point1)
      }
      HStack(spacing: MeetPRSpacing.sm) {
        if let systemImage {
          Image(systemName: systemImage)
            .accessibilityHidden(true)
        }
        Text(title)
      }
      .font(Font.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textSecondary)
      .lineLimit(2)
      .multilineTextAlignment(.center)
      .padding(.horizontal, MeetPRSpacing.lg)
      .padding(.vertical, MeetPRSpacing.point14)
      .frame(maxWidth: isFullWidth ? .infinity : nil)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.pill)
        .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.pill))
  }
}
