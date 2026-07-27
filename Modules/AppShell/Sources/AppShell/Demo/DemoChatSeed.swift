import ChatUI
import CoreModels
import Foundation
import StudentKit

@available(iOS 17.0, macOS 14.0, *)
public enum DemoChatSeed {
  public static func make(for user: User) -> ChatDemoSeed {
    guard user.role == .coachedStudent else {
      return .coach()
    }

    let base = ChatDemoSeed.student()
    let firstMessageAt = Date().addingTimeInterval(-900)
    let messages = base.messagesByConversationID.mapValues { items in
      items.enumerated().map { index, message in
        let senderID =
          message.senderID == ChatDemoSeed.coachUserID
          ? StudentDemoSeed.coachID
          : user.id
        return ChatMessage(
          id: message.id,
          conversationID: message.conversationID,
          seq: message.seq,
          senderID: senderID,
          kind: message.kind,
          text: message.text,
          attachmentID: message.attachmentID,
          imageURL: message.imageURL,
          imageExpiresIn: message.imageExpiresIn,
          clientID: message.clientID,
          createdAt: firstMessageAt.addingTimeInterval(Double(index) * 300)
        )
      }
    }
    let conversations = base.conversations.map { conversation in
      ChatConversation(
        id: conversation.id,
        otherPartyID: StudentDemoSeed.coachID,
        otherPartyName: "演示教练",
        lastMessagePreview: conversation.lastMessagePreview,
        lastMessageAt: messages[conversation.id]?.last?.createdAt,
        unreadCount: conversation.unreadCount,
        myLastRead: conversation.myLastRead,
        otherLastRead: conversation.otherLastRead
      )
    }
    return ChatDemoSeed(
      conversations: conversations,
      messagesByConversationID: messages,
      otherPartyNames: [StudentDemoSeed.coachID: "演示教练"]
    )
  }
}
