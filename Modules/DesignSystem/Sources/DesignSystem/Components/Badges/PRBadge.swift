import SwiftUI

@MainActor
public struct PRBadge: View {
  public enum Style: Sendable {
    case newPR
    // swiftlint:disable:next identifier_name
    case pr

    var title: String {
      switch self {
      case .newPR: "NEW PR"
      case .pr: "PR"
      }
    }
  }

  private let style: Style
  private let isVisible: Bool

  public init(_ style: Style = .newPR, isVisible: Bool = true) {
    self.style = style
    self.isVisible = isVisible
  }

  public var body: some View {
    Group {
      if isVisible {
        Text(style.title)
          .font(
            .system(size: MeetPRFontMetrics.captionSize, weight: .semibold, design: .monospaced)
          )
          .tracking(0.88)
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.MeetPR.brandRed)
          .clipShape(.capsule)
          .accessibilityLabel(style.title)
          .accessibilityHint("Indicates a personal record.")
      }
    }
    .sensoryFeedback(.success, trigger: isVisible)
  }
}

#Preview("PRBadge") {
  HStack(spacing: MeetPRSpacing.sm) {
    PRBadge(.newPR)
    PRBadge(.pr)
    PRBadge(.newPR, isVisible: false)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("PRBadge Light") {
  PRBadge(.newPR)
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
