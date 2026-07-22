import DesignSystem
import SwiftUI

@MainActor
public struct ChatEntryButton: View {
  private let unreadCount: Int
  private let action: @MainActor () -> Void

  public init(unreadCount: Int, action: @escaping @MainActor () -> Void) {
    self.unreadCount = unreadCount
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Image(systemName: "message")
        .font(.body.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
          if unreadCount > 0 {
            ChatUnreadBadge(count: unreadCount)
          }
        }
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(ChatStrings.messages)
    .accessibilityValue(
      unreadCount > 0 ? "\(unreadCount) \(ChatStrings.unread)" : ""
    )
  }
}

private struct ChatUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(.caption2.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 5)
      .frame(minWidth: 18, minHeight: 18)
      .background(Color.MeetPR.brandRed, in: .capsule)
      .accessibilityHidden(true)
  }
}
