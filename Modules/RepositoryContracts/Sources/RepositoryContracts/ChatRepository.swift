import CoreModels
import Foundation

public struct ChatMessageQuery: Equatable, Sendable {
  public enum Mode: Equatable, Sendable {
    case latest
    case after(seq: Int)
    case before(seq: Int)
  }

  public let mode: Mode
  public let limit: Int

  private init(mode: Mode, limit: Int) {
    self.mode = mode
    self.limit = limit
  }

  public static func latest(limit: Int) throws -> ChatMessageQuery {
    try validate(limit: limit)
    return ChatMessageQuery(mode: .latest, limit: limit)
  }

  public static func after(seq: Int, limit: Int) throws -> ChatMessageQuery {
    try validate(limit: limit)
    try validate(seq: seq)
    return ChatMessageQuery(mode: .after(seq: seq), limit: limit)
  }

  public static func before(seq: Int, limit: Int) throws -> ChatMessageQuery {
    try validate(limit: limit)
    try validate(seq: seq)
    return ChatMessageQuery(mode: .before(seq: seq), limit: limit)
  }

  private static func validate(limit: Int) throws {
    guard (1...100).contains(limit) else {
      throw ChatQueryValidationError.invalidLimit(limit)
    }
  }

  private static func validate(seq: Int) throws {
    guard seq >= 1 else {
      throw ChatQueryValidationError.invalidSeq(seq)
    }
  }
}

public enum ChatQueryValidationError: Error, Equatable, Sendable {
  case invalidLimit(Int)
  case invalidSeq(Int)
}

public struct ChatMessagePage: Equatable, Sendable {
  public let messages: [ChatMessage]
  public let otherLastRead: ChatCursor?
  public let hasMore: Bool

  public init(messages: [ChatMessage], otherLastRead: ChatCursor?, hasMore: Bool) {
    self.messages = messages
    self.otherLastRead = otherLastRead
    self.hasMore = hasMore
  }
}

public struct ChatReadState: Equatable, Sendable {
  public let myLastRead: ChatCursor
  public let unreadCount: Int

  public init(myLastRead: ChatCursor, unreadCount: Int) {
    self.myLastRead = myLastRead
    self.unreadCount = unreadCount
  }
}

public enum ChatRepositoryError: Error, Equatable, Sendable {
  case bindRequired
  case conversationNotFound
  case invalidAttachment
  /// Backend rejected a read cursor as not belonging to this conversation
  /// (`400 CHAT_INVALID_CURSOR`, backend spec 024). Reachable when a stale
  /// message id outlives the conversation it was read from.
  case invalidCursor
}

public protocol ChatRepository: Sendable {
  func fetchConversations() async throws -> [ChatConversation]
  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation
  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage
  func sendText(in conversationID: UUID, text: String, clientID: String) async throws
    -> ChatMessage
  func sendImage(in conversationID: UUID, imageData: Data, clientID: String) async throws
    -> ChatMessage
  func sendSetRef(
    in conversationID: UUID,
    body: String,
    setRef: SetRefV1,
    videoID: UUID?,
    clientID: String
  ) async throws -> ChatMessage
  func markRead(in conversationID: UUID, upTo messageID: UUID) async throws -> ChatReadState
}

extension ChatRepository {
  /// Non-network repositories retain a text fallback until they opt into
  /// structured set-card storage. The production network repository overrides
  /// this requirement with the full `set_ref` wire request.
  public func sendSetRef(
    in conversationID: UUID,
    body: String,
    setRef: SetRefV1,
    videoID: UUID?,
    clientID: String
  ) async throws -> ChatMessage {
    try await sendText(in: conversationID, text: body, clientID: clientID)
  }
}
