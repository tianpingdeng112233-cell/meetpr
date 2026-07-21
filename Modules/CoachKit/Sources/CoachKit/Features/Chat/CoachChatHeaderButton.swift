import ChatUI
import SwiftUI

@MainActor
struct CoachChatHeaderButton: View {
  let chat: CoachChatContext?
  let action: @MainActor () -> Void

  var body: some View {
    if let chat {
      ChatEntryButton(
        unreadCount: chat.inbox.totalUnread,
        action: action
      )
    }
  }
}
