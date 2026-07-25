import Testing

@testable import ChatUI

@MainActor
@Test("chat unread badge is a red count badge, not action gold")
func chatUnreadBadgeUsesDanger() {
  #expect(ChatEntryButton.unreadTone == .unreadBadge)
  #expect(ChatEntryButton.unreadTone != .action)
}
