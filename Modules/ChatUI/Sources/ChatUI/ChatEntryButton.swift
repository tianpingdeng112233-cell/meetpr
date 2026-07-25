import DesignSystem
import SwiftUI

@MainActor
public struct ChatEntryButton: View {
  static let unreadTone = MeetPRSemanticTone.unread

  private let unreadCount: Int
  private let action: @MainActor () -> Void

  public init(unreadCount: Int, action: @escaping @MainActor () -> Void) {
    self.unreadCount = unreadCount
    self.action = action
  }

  public var body: some View {
    HeaderChatButton(
      unreadCount: unreadCount,
      accessibilityLabel: ChatStrings.messages
    ) {
      action()
    }
    .accessibilityValue(
      unreadCount > 0 ? "\(unreadCount) \(ChatStrings.unread)" : ""
    )
  }
}
