import SwiftUI

@MainActor
public struct HeaderChatButton: View {
  public static let unreadTone = MeetPRSemanticTone.unread

  private let unreadCount: Int
  private let accessibilityLabel: String
  private let action: @MainActor () -> Void

  public init(
    unreadCount: Int,
    accessibilityLabel: String,
    action: @escaping @MainActor () -> Void
  ) {
    self.unreadCount = unreadCount
    self.accessibilityLabel = accessibilityLabel
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Image(systemName: "message")
        .font(
          .MeetPR.system(
            size: MeetPRFontMetrics.size21,
            weight: .medium
          )
        )
        .foregroundStyle(Color.MeetPR.textPrimary)
        .frame(
          width: MeetPRSpacing.minimumHitTarget,
          height: MeetPRSpacing.minimumHitTarget
        )
        .background(Color.MeetPR.surfaceCard, in: .circle)
        .overlay(alignment: .topTrailing) {
          if unreadCount > 0 {
            HeaderUnreadBadge(count: unreadCount)
          }
        }
        .contentShape(.circle)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(unreadCount > 0 ? unreadCount.formatted() : "")
  }
}

private struct HeaderUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(
        .MeetPR.system(
          size: MeetPRFontMetrics.size10,
          weight: .bold,
          design: .monospaced
        )
      )
      .foregroundStyle(Color.MeetPR.ctaTopHighlight)
      .padding(.horizontal, MeetPRSpacing.space1)
      .frame(
        minWidth: MeetPRSpacing.point18,
        minHeight: MeetPRSpacing.point18
      )
      .background(HeaderChatButton.unreadTone.color, in: .capsule)
      .accessibilityHidden(true)
  }
}
