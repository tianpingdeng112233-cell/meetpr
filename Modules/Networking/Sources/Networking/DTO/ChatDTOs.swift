import CoreModels
import Foundation

public struct ChatCursorDTO: Codable, Equatable, Sendable {
  public let messageID: UUID
  public let seq: Int

  public init(messageID: UUID, seq: Int) {
    self.messageID = messageID
    self.seq = seq
  }

  public func toDomain() -> ChatCursor {
    ChatCursor(messageID: messageID, seq: seq)
  }

  private enum CodingKeys: String, CodingKey {
    case messageID = "messageId"
    case seq
  }
}

public struct ChatOtherPartyDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let displayName: String

  public init(id: UUID, displayName: String) {
    self.id = id
    self.displayName = displayName
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case displayName
  }
}

public struct ChatLastMessageDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let seq: Int
  public let kind: ChatMessageKind
  public let preview: String
  public let createdAt: Date
  public let senderID: UUID

  public init(
    id: UUID,
    seq: Int,
    kind: ChatMessageKind,
    preview: String,
    createdAt: Date,
    senderID: UUID
  ) {
    self.id = id
    self.seq = seq
    self.kind = kind
    self.preview = preview
    self.createdAt = createdAt
    self.senderID = senderID
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case seq
    case kind
    case preview
    case createdAt
    case senderID = "senderId"
  }
}

public struct ChatConversationDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let otherParty: ChatOtherPartyDTO
  public let lastMessage: ChatLastMessageDTO?
  public let lastMessageAt: Date?
  public let unreadCount: Int
  public let myLastRead: ChatCursorDTO?
  public let otherLastRead: ChatCursorDTO?

  public init(
    id: UUID,
    otherParty: ChatOtherPartyDTO,
    lastMessage: ChatLastMessageDTO?,
    lastMessageAt: Date?,
    unreadCount: Int,
    myLastRead: ChatCursorDTO?,
    otherLastRead: ChatCursorDTO?
  ) {
    self.id = id
    self.otherParty = otherParty
    self.lastMessage = lastMessage
    self.lastMessageAt = lastMessageAt
    self.unreadCount = unreadCount
    self.myLastRead = myLastRead
    self.otherLastRead = otherLastRead
  }

  public func toDomain() -> ChatConversation {
    ChatConversation(
      id: id,
      otherPartyID: otherParty.id,
      otherPartyName: otherParty.displayName,
      lastMessagePreview: lastMessage?.preview,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      myLastRead: myLastRead?.toDomain(),
      otherLastRead: otherLastRead?.toDomain()
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case otherParty
    case lastMessage
    case lastMessageAt
    case unreadCount
    case myLastRead
    case otherLastRead
  }
}

public struct ChatMessageDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let conversationID: UUID
  public let seq: Int
  public let senderID: UUID
  public let kind: ChatMessageKind
  public let body: String?
  public let attachmentID: UUID?
  public let imageURL: URL?
  public let imageExpiresIn: Int?
  public let setRef: SetRefV1?
  public let videoURL: URL?
  public let videoExpiresIn: Int?
  public let clientID: String
  public let createdAt: Date

  public init(
    id: UUID,
    conversationID: UUID,
    seq: Int,
    senderID: UUID,
    kind: ChatMessageKind,
    body: String?,
    attachmentID: UUID?,
    imageURL: URL?,
    imageExpiresIn: Int?,
    setRef: SetRefV1? = nil,
    videoURL: URL? = nil,
    videoExpiresIn: Int? = nil,
    clientID: String,
    createdAt: Date
  ) {
    self.id = id
    self.conversationID = conversationID
    self.seq = seq
    self.senderID = senderID
    self.kind = kind
    self.body = body
    self.attachmentID = attachmentID
    self.imageURL = imageURL
    self.imageExpiresIn = imageExpiresIn
    self.setRef = setRef
    self.videoURL = videoURL
    self.videoExpiresIn = videoExpiresIn
    self.clientID = clientID
    self.createdAt = createdAt
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    conversationID = try container.decode(UUID.self, forKey: .conversationID)
    seq = try container.decode(Int.self, forKey: .seq)
    senderID = try container.decode(UUID.self, forKey: .senderID)
    kind = try container.decode(ChatMessageKind.self, forKey: .kind)
    body = try container.decodeIfPresent(String.self, forKey: .body)
    attachmentID = try container.decodeIfPresent(UUID.self, forKey: .attachmentID)
    imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
    imageExpiresIn = try container.decodeIfPresent(Int.self, forKey: .imageExpiresIn)
    setRef = try? container.decode(SetRefV1ReadValue.self, forKey: .setRef).value
    videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
    videoExpiresIn = try container.decodeIfPresent(Int.self, forKey: .videoExpiresIn)
    clientID = try container.decode(String.self, forKey: .clientID)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  public func toDomain() -> ChatMessage {
    ChatMessage(
      id: id,
      conversationID: conversationID,
      seq: seq,
      senderID: senderID,
      kind: kind,
      text: body,
      attachmentID: attachmentID,
      imageURL: imageURL,
      imageExpiresIn: imageExpiresIn,
      setRef: setRef,
      videoURL: videoURL,
      videoExpiresIn: videoExpiresIn,
      clientID: clientID,
      createdAt: createdAt
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case conversationID = "conversationId"
    case seq
    case senderID = "senderId"
    case kind
    case body
    case attachmentID = "attachmentId"
    case imageURL = "imageUrl"
    case imageExpiresIn
    case setRef
    case videoURL = "videoUrl"
    case videoExpiresIn
    case clientID = "clientId"
    case createdAt
  }
}

public struct ChatOpenConversationRequestDTO: Codable, Equatable, Sendable {
  public let otherUserID: UUID

  public init(otherUserID: UUID) {
    self.otherUserID = otherUserID
  }

  private enum CodingKeys: String, CodingKey {
    case otherUserID = "otherUserId"
  }
}

public struct ChatConversationResponseDTO: Codable, Equatable, Sendable {
  public let conversation: ChatConversationDTO

  public init(conversation: ChatConversationDTO) {
    self.conversation = conversation
  }

  private enum CodingKeys: String, CodingKey {
    case conversation
  }
}

public struct ChatConversationsResponseDTO: Codable, Equatable, Sendable {
  public let conversations: [ChatConversationDTO]

  public init(conversations: [ChatConversationDTO]) {
    self.conversations = conversations
  }

  private enum CodingKeys: String, CodingKey {
    case conversations
  }
}

public struct ChatMessagesMetaDTO: Codable, Equatable, Sendable {
  public let otherLastRead: ChatCursorDTO?
  public let hasMore: Bool

  public init(otherLastRead: ChatCursorDTO?, hasMore: Bool) {
    self.otherLastRead = otherLastRead
    self.hasMore = hasMore
  }

  private enum CodingKeys: String, CodingKey {
    case otherLastRead
    case hasMore
  }
}

public struct ChatMessagesResponseDTO: Codable, Equatable, Sendable {
  public let messages: [ChatMessageDTO]
  public let meta: ChatMessagesMetaDTO

  public init(messages: [ChatMessageDTO], meta: ChatMessagesMetaDTO) {
    self.messages = messages
    self.meta = meta
  }

  private enum CodingKeys: String, CodingKey {
    case messages
    case meta
  }
}

public struct ChatSendMessageRequestDTO: Codable, Equatable, Sendable {
  public let kind: ChatMessageKind
  public let body: String?
  public let attachmentID: UUID?
  public let clientID: String
  public let setRef: SetRefV1?
  public let videoID: UUID?

  public init(
    kind: ChatMessageKind,
    body: String? = nil,
    attachmentID: UUID? = nil,
    clientID: String,
    setRef: SetRefV1? = nil,
    videoID: UUID? = nil
  ) {
    self.kind = kind
    self.body = body
    self.attachmentID = attachmentID
    self.clientID = clientID
    self.setRef = setRef
    self.videoID = videoID
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case body
    case attachmentID = "attachmentId"
    case clientID = "clientId"
    case setRef
    case videoID
  }
}

public struct ChatMessageResponseDTO: Codable, Equatable, Sendable {
  public let message: ChatMessageDTO

  public init(message: ChatMessageDTO) {
    self.message = message
  }

  private enum CodingKeys: String, CodingKey {
    case message
  }
}

public struct ChatReadRequestDTO: Codable, Equatable, Sendable {
  public let messageID: UUID

  public init(messageID: UUID) {
    self.messageID = messageID
  }

  private enum CodingKeys: String, CodingKey {
    case messageID = "messageId"
  }
}

public struct ChatReadResponseDTO: Codable, Equatable, Sendable {
  public let myLastRead: ChatCursorDTO
  public let unreadCount: Int

  public init(myLastRead: ChatCursorDTO, unreadCount: Int) {
    self.myLastRead = myLastRead
    self.unreadCount = unreadCount
  }

  private enum CodingKeys: String, CodingKey {
    case myLastRead
    case unreadCount
  }
}
