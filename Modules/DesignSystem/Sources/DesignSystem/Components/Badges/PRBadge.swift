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
          .font(.MeetPR.mono(size: 10, weight: .bold))
          .tracking(0.8)
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, MeetPRSpacing.sm)
          .padding(.vertical, MeetPRSpacing.xs)
          .background(Color.MeetPR.goldSoft)
          .overlay {
            Capsule()
              .stroke(Color.MeetPR.gold500.opacity(0.44), lineWidth: 1)
          }
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
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("PRBadge Light") {
  PRBadge(.newPR)
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
