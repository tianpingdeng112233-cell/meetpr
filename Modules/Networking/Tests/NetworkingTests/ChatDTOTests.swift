import CoreModels
import Foundation
import Testing

@testable import Networking

@Test func chatConversationFixtureDecodesEveryWireField() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatConversationResponseDTO.self,
    from: Data(ChatWireFixture.conversationResponse.utf8)
  )
  let conversation = response.conversation

  #expect(conversation.id == ChatWireFixture.conversationID)
  #expect(conversation.otherParty.id == ChatWireFixture.otherUserID)
  #expect(conversation.otherParty.displayName == "王晨曦")
  #expect(conversation.lastMessage?.id == ChatWireFixture.textMessageID)
  #expect(conversation.lastMessage?.seq == 42)
  #expect(conversation.lastMessage?.kind == .text)
  #expect(conversation.lastMessage?.preview == "明天深蹲加到 140")
  #expect(conversation.lastMessage?.senderID == ChatWireFixture.otherUserID)
  #expect(conversation.lastMessageAt != nil)
  #expect(conversation.unreadCount == 2)
  #expect(conversation.myLastRead?.messageID == ChatWireFixture.readMessageID)
  #expect(conversation.myLastRead?.seq == 40)
  #expect(conversation.otherLastRead?.messageID == ChatWireFixture.textMessageID)
  #expect(conversation.otherLastRead?.seq == 42)

  let domain = conversation.toDomain()
  #expect(domain.otherPartyID == ChatWireFixture.otherUserID)
  #expect(domain.lastMessagePreview == "明天深蹲加到 140")
  #expect(domain.myLastRead?.seq == 40)
}

@Test func emptyChatConversationFixtureDecodesNullableFields() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatConversationsResponseDTO.self,
    from: Data(ChatWireFixture.emptyConversationsResponse.utf8)
  )
  let conversation = try #require(response.conversations.first)

  #expect(conversation.lastMessage == nil)
  #expect(conversation.lastMessageAt == nil)
  #expect(conversation.myLastRead == nil)
  #expect(conversation.otherLastRead == nil)
  #expect(conversation.unreadCount == 0)
}

@Test func chatMessagesFixtureDecodesKindsAndNullableMatrix() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatMessagesResponseDTO.self,
    from: Data(ChatWireFixture.messagesResponse.utf8)
  )
  try #require(response.messages.count == 2)

  let text = response.messages[0]
  #expect(text.seq == 40)
  #expect(text.kind == .text)
  #expect(text.body == "先做两组热身")
  #expect(text.attachmentID == nil)
  #expect(text.imageURL == nil)
  #expect(text.imageExpiresIn == nil)
  #expect(text.setRef == nil)
  #expect(text.videoURL == nil)
  #expect(text.videoExpiresIn == nil)
  #expect(text.clientID == "cli-text")

  let image = response.messages[1]
  #expect(image.id == ChatWireFixture.imageMessageID)
  #expect(image.conversationID == ChatWireFixture.conversationID)
  #expect(image.seq == 41)
  #expect(image.senderID == ChatWireFixture.otherUserID)
  #expect(image.kind == .image)
  #expect(image.body == nil)
  #expect(image.attachmentID == ChatWireFixture.attachmentID)
  #expect(image.imageURL?.absoluteString == "https://oss.example.test/chat/image.jpg?signature=abc")
  #expect(image.imageExpiresIn == 900)
  #expect(image.setRef == nil)
  #expect(image.videoURL == nil)
  #expect(image.videoExpiresIn == nil)
  #expect(image.clientID == "cli-xyz")
  #expect(response.meta.otherLastRead?.messageID == ChatWireFixture.readMessageID)
  #expect(response.meta.otherLastRead?.seq == 40)
  #expect(response.meta.hasMore)
}

@Test func chatMessageFixtureRejectsMissingClientIDAndWrongSequenceType() {
  #expect(throws: (any Error).self) {
    try MeetPRCodec.decoder.decode(
      ChatMessageResponseDTO.self,
      from: Data(ChatWireFixture.messageMissingClientID.utf8)
    )
  }
  #expect(throws: (any Error).self) {
    try MeetPRCodec.decoder.decode(
      ChatMessageResponseDTO.self,
      from: Data(ChatWireFixture.messageWithStringSequence.utf8)
    )
  }
}

@Test func chatRequestDTOsEncodeExactSnakeCaseBodies() throws {
  let open = try jsonObject(
    ChatOpenConversationRequestDTO(otherUserID: ChatWireFixture.otherUserID)
  )
  #expect(open.count == 1)
  #expect(open["other_user_id"] as? String == ChatWireFixture.otherUserID.uuidString)

  let text = try jsonObject(
    ChatSendMessageRequestDTO(kind: .text, body: "明天加重量", clientID: "cli-text")
  )
  #expect(text.count == 3)
  #expect(text["kind"] as? String == "text")
  #expect(text["body"] as? String == "明天加重量")
  #expect(text["client_id"] as? String == "cli-text")
  #expect(text["attachment_id"] == nil)

  let image = try jsonObject(
    ChatSendMessageRequestDTO(
      kind: .image,
      attachmentID: ChatWireFixture.attachmentID,
      clientID: "cli-image"
    )
  )
  #expect(image.count == 3)
  #expect(image["kind"] as? String == "image")
  #expect(image["attachment_id"] as? String == ChatWireFixture.attachmentID.uuidString)
  #expect(image["client_id"] as? String == "cli-image")
  #expect(image["body"] == nil)

  let read = try jsonObject(ChatReadRequestDTO(messageID: ChatWireFixture.imageMessageID))
  #expect(read.count == 1)
  #expect(read["message_id"] as? String == ChatWireFixture.imageMessageID.uuidString)
}

@Test func chatReadFixtureDecodesCursorObject() throws {
  let response = try MeetPRCodec.decoder.decode(
    ChatReadResponseDTO.self,
    from: Data(ChatWireFixture.readResponse.utf8)
  )
  #expect(response.myLastRead.messageID == ChatWireFixture.imageMessageID)
  #expect(response.myLastRead.seq == 41)
  #expect(response.unreadCount == 1)
}

@Test func attachmentKindChatImageRoundTripsWireValue() throws {
  let data = try MeetPRCodec.encoder.encode(AttachmentKindDTO.chatImage)
  #expect(String(data: data, encoding: .utf8) == #""chat_image""#)
  #expect(try MeetPRCodec.decoder.decode(AttachmentKindDTO.self, from: data) == .chatImage)
}

private func jsonObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
  let data = try MeetPRCodec.encoder.encode(value)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

enum ChatWireFixture {
  static let conversationID = testUUID(1)
  static let otherUserID = testUUID(2)
  static let textMessageID = testUUID(3)
  static let imageMessageID = testUUID(4)
  static let readMessageID = testUUID(5)
  static let attachmentID = testUUID(6)

  static var conversationResponse: String {
    """
    {
      "conversation": {
        "id": "\(conversationID.uuidString)",
        "other_party": {
          "id": "\(otherUserID.uuidString)",
          "display_name": "王晨曦"
        },
        "last_message": {
          "id": "\(textMessageID.uuidString)",
          "seq": 42,
          "kind": "text",
          "preview": "明天深蹲加到 140",
          "created_at": "2026-07-20T09:12:30.123Z",
          "sender_id": "\(otherUserID.uuidString)"
        },
        "last_message_at": "2026-07-20T09:12:30.123Z",
        "unread_count": 2,
        "my_last_read": {"message_id": "\(readMessageID.uuidString)", "seq": 40},
        "other_last_read": {"message_id": "\(textMessageID.uuidString)", "seq": 42}
      }
    }
    """
  }

  static var emptyConversationsResponse: String {
    """
    {
      "conversations": [{
        "id": "\(conversationID.uuidString)",
        "other_party": {"id": "\(otherUserID.uuidString)", "display_name": "王晨曦"},
        "last_message": null,
        "last_message_at": null,
        "unread_count": 0,
        "my_last_read": null,
        "other_last_read": null
      }]
    }
    """
  }

  static var messagesResponse: String {
    """
    {
      "messages": [
        {
          "id": "\(readMessageID.uuidString)",
          "conversation_id": "\(conversationID.uuidString)",
          "seq": 40,
          "sender_id": "\(otherUserID.uuidString)",
          "kind": "text",
          "body": "先做两组热身",
          "attachment_id": null,
          "image_url": null,
          "image_expires_in": null,
          "client_id": "cli-text",
          "created_at": "2026-07-20T09:08:00.000Z"
        },
        {
          "id": "\(imageMessageID.uuidString)",
          "conversation_id": "\(conversationID.uuidString)",
          "seq": 41,
          "sender_id": "\(otherUserID.uuidString)",
          "kind": "image",
          "body": null,
          "attachment_id": "\(attachmentID.uuidString)",
          "image_url": "https://oss.example.test/chat/image.jpg?signature=abc",
          "image_expires_in": 900,
          "client_id": "cli-xyz",
          "created_at": "2026-07-20T09:10:00.000Z"
        }
      ],
      "meta": {
        "other_last_read": {"message_id": "\(readMessageID.uuidString)", "seq": 40},
        "has_more": true
      }
    }
    """
  }

  static var messageMissingClientID: String {
    messageResponse(clientIDLine: "", sequence: "41")
  }

  static var messageWithStringSequence: String {
    messageResponse(clientIDLine: #""client_id": "cli-xyz","#, sequence: #""41""#)
  }

  static var readResponse: String {
    """
    {
      "my_last_read": {"message_id": "\(imageMessageID.uuidString)", "seq": 41},
      "unread_count": 1
    }
    """
  }

  static func messageResponse(clientIDLine: String, sequence: String) -> String {
    """
    {
      "message": {
        "id": "\(imageMessageID.uuidString)",
        "conversation_id": "\(conversationID.uuidString)",
        "seq": \(sequence),
        "sender_id": "\(otherUserID.uuidString)",
        "kind": "image",
        "body": null,
        "attachment_id": "\(attachmentID.uuidString)",
        "image_url": null,
        "image_expires_in": null,
        \(clientIDLine)
        "created_at": "2026-07-20T09:10:00.000Z"
      }
    }
    """
  }

  private static func testUUID(_ suffix: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x5A, suffix))
  }
}
