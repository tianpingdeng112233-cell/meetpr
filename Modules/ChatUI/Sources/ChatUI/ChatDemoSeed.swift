import CoreModels
import Foundation

public struct ChatDemoSeed: Sendable {
  public static let coachUserID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x58, 0x01)
  )
  public static let studentUserID = UUID(
    uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x58, 0x02)
  )

  public let conversations: [ChatConversation]
  public let messagesByConversationID: [UUID: [ChatMessage]]
  public let otherPartyNames: [UUID: String]

  public init(
    conversations: [ChatConversation],
    messagesByConversationID: [UUID: [ChatMessage]],
    otherPartyNames: [UUID: String] = [:]
  ) {
    self.conversations = conversations
    self.messagesByConversationID = messagesByConversationID
    self.otherPartyNames = otherPartyNames
  }

  public static func coach() -> ChatDemoSeed {
    let firstStudentID = coachPreviewStudentID(4)
    let secondStudentID = coachPreviewStudentID(8)
    let firstConversationID = uuid(0x11)
    let secondConversationID = uuid(0x12)
    let firstMessage = coachTextMessage(
      conversationID: firstConversationID,
      senderID: firstStudentID
    )
    let secondMessage = coachImageMessage(
      conversationID: secondConversationID,
      senderID: secondStudentID
    )
    return ChatDemoSeed(
      conversations: [
        conversation(
          id: secondConversationID,
          otherPartyID: secondStudentID,
          otherPartyName: "李嘉宁",
          lastMessage: secondMessage
        ),
        conversation(
          id: firstConversationID,
          otherPartyID: firstStudentID,
          otherPartyName: "王晨曦",
          lastMessage: firstMessage
        ),
      ],
      messagesByConversationID: [
        firstConversationID: [firstMessage],
        secondConversationID: [secondMessage],
      ],
      otherPartyNames: [firstStudentID: "王晨曦", secondStudentID: "李嘉宁"]
    )
  }

  public static func student() -> ChatDemoSeed {
    let conversationID = uuid(0x41)
    let coachMessageID = uuid(0x42)
    let studentMessageID = uuid(0x43)
    let coachCreatedAt = Date(timeIntervalSince1970: 1_768_900_000)
    let studentCreatedAt = Date(timeIntervalSince1970: 1_768_900_600)
    let coachMessage = ChatMessage(
      id: coachMessageID,
      conversationID: conversationID,
      seq: 1,
      senderID: coachUserID,
      kind: .text,
      text: "明天深蹲加到 140。",
      attachmentID: nil,
      imageURL: nil,
      imageExpiresIn: nil,
      clientID: "demo-coach-text-1",
      createdAt: coachCreatedAt
    )
    let studentMessage = ChatMessage(
      id: studentMessageID,
      conversationID: conversationID,
      seq: 2,
      senderID: studentUserID,
      kind: .text,
      text: "收到。",
      attachmentID: nil,
      imageURL: nil,
      imageExpiresIn: nil,
      clientID: "demo-student-text-2",
      createdAt: studentCreatedAt
    )
    return ChatDemoSeed(
      conversations: [
        ChatConversation(
          id: conversationID,
          otherPartyID: coachUserID,
          otherPartyName: "周教练",
          lastMessagePreview: studentMessage.text,
          lastMessageAt: studentCreatedAt,
          unreadCount: 0,
          myLastRead: ChatCursor(messageID: coachMessageID, seq: 1),
          otherLastRead: ChatCursor(messageID: studentMessageID, seq: 2)
        )
      ],
      messagesByConversationID: [conversationID: [coachMessage, studentMessage]],
      otherPartyNames: [coachUserID: "周教练"]
    )
  }

  private static func conversation(
    id: UUID,
    otherPartyID: UUID,
    otherPartyName: String,
    lastMessage: ChatMessage
  ) -> ChatConversation {
    ChatConversation(
      id: id,
      otherPartyID: otherPartyID,
      otherPartyName: otherPartyName,
      lastMessagePreview: lastMessage.kind == .image ? "[图片]" : lastMessage.text,
      lastMessageAt: lastMessage.createdAt,
      unreadCount: 1,
      myLastRead: nil,
      otherLastRead: nil
    )
  }

  private static func coachTextMessage(
    conversationID: UUID,
    senderID: UUID
  ) -> ChatMessage {
    ChatMessage(
      id: uuid(0x21),
      conversationID: conversationID,
      seq: 1,
      senderID: senderID,
      kind: .text,
      text: "教练，今天最后一组完成了。",
      attachmentID: nil,
      imageURL: nil,
      imageExpiresIn: nil,
      clientID: "demo-student-text-1",
      createdAt: Date(timeIntervalSince1970: 1_768_900_200)
    )
  }

  private static func coachImageMessage(
    conversationID: UUID,
    senderID: UUID
  ) -> ChatMessage {
    ChatMessage(
      id: uuid(0x22),
      conversationID: conversationID,
      seq: 1,
      senderID: senderID,
      kind: .image,
      text: nil,
      attachmentID: uuid(0x31),
      imageURL: URL(string: "https://demo.invalid/chat/image.jpg"),
      imageExpiresIn: 900,
      clientID: "demo-student-image-1",
      createdAt: Date(timeIntervalSince1970: 1_768_900_800)
    )
  }

  private static func uuid(_ suffix: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x58, suffix))
  }

  /// Matches the coach preview roster IDs produced by
  /// `CoachDemoSeed.previewStudentID`. This stays local to avoid a ChatUI →
  /// CoachKit dependency cycle.
  private static func coachPreviewStudentID(_ suffix: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, suffix))
  }
}
