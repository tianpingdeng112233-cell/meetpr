import CoreModels
import Foundation
import RepositoryContracts

public enum InMemoryChatRepositoryError: Error, Equatable, Sendable {
  case messageNotFound
  case emptyImageData
}

public actor InMemoryChatRepository: ChatRepository {
  private let currentUserID: UUID
  private let otherPartyNames: [UUID: String]
  private var conversations: [ChatConversation]
  private var messagesByConversationID: [UUID: [ChatMessage]]

  public init(currentUserID: UUID, seed: ChatDemoSeed) {
    self.currentUserID = currentUserID
    otherPartyNames = seed.otherPartyNames
    conversations = seed.conversations
    messagesByConversationID = seed.messagesByConversationID
  }

  public func fetchConversations() async throws -> [ChatConversation] {
    conversations
      .map(conversationForCurrentUser)
      .sorted(by: Self.conversationOrder)
  }

  public func openConversation(
    withOtherParty otherPartyID: UUID
  ) async throws -> ChatConversation {
    if let conversation = conversations.first(where: { $0.otherPartyID == otherPartyID }) {
      return conversationForCurrentUser(conversation)
    }

    let conversation = ChatConversation(
      id: UUID(),
      otherPartyID: otherPartyID,
      otherPartyName: otherPartyNames[otherPartyID] ?? "",
      lastMessagePreview: nil,
      lastMessageAt: nil,
      unreadCount: 0,
      myLastRead: nil,
      otherLastRead: nil
    )
    conversations.append(conversation)
    messagesByConversationID[conversation.id] = []
    return conversation
  }

  public func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    guard let conversation = conversations.first(where: { $0.id == conversationID }) else {
      throw ChatRepositoryError.conversationNotFound
    }
    let ascending = messagesByConversationID[conversationID, default: []]
      .sorted { $0.seq < $1.seq }
    let candidates: [ChatMessage]
    let page: [ChatMessage]

    switch query.mode {
    case .latest:
      candidates = ascending
      page = Array(candidates.suffix(query.limit).reversed())
    case .after(let seq):
      candidates = ascending.filter { $0.seq > seq }
      page = Array(candidates.prefix(query.limit))
    case .before(let seq):
      candidates = ascending.filter { $0.seq < seq }
      page = Array(candidates.suffix(query.limit).reversed())
    }

    return ChatMessagePage(
      messages: page,
      otherLastRead: conversation.otherLastRead,
      hasMore: candidates.count > query.limit
    )
  }

  public func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    try appendMessage(
      in: conversationID,
      kind: .text,
      text: text,
      attachmentID: nil,
      clientID: clientID
    )
  }

  public func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    guard !imageData.isEmpty else {
      throw InMemoryChatRepositoryError.emptyImageData
    }
    return try appendMessage(
      in: conversationID,
      kind: .image,
      text: nil,
      attachmentID: UUID(),
      clientID: clientID
    )
  }

  public func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID })
    else {
      throw ChatRepositoryError.conversationNotFound
    }
    guard
      let target = messagesByConversationID[conversationID]?.first(where: { $0.id == messageID })
    else {
      throw InMemoryChatRepositoryError.messageNotFound
    }

    let conversation = conversations[conversationIndex]
    let cursor: ChatCursor
    if let existing = conversation.myLastRead, existing.seq >= target.seq {
      cursor = existing
    } else {
      cursor = ChatCursor(messageID: target.id, seq: target.seq)
    }
    let unreadCount = unreadCount(in: conversationID, after: cursor.seq)
    conversations[conversationIndex] = replacing(
      conversation,
      unreadCount: unreadCount,
      myLastRead: cursor
    )
    return ChatReadState(myLastRead: cursor, unreadCount: unreadCount)
  }

  private func appendMessage(
    in conversationID: UUID,
    kind: ChatMessageKind,
    text: String?,
    attachmentID: UUID?,
    clientID: String
  ) throws -> ChatMessage {
    guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID })
    else {
      throw ChatRepositoryError.conversationNotFound
    }
    if let existing = messagesByConversationID[conversationID]?.first(where: {
      $0.senderID == currentUserID && $0.clientID == clientID
    }) {
      return existing
    }

    var messages = messagesByConversationID[conversationID, default: []]
    let nextSequence = (messages.map(\.seq).max() ?? 0) + 1
    let createdAt = Date()
    let message = ChatMessage(
      id: UUID(),
      conversationID: conversationID,
      seq: nextSequence,
      senderID: currentUserID,
      kind: kind,
      text: text,
      attachmentID: attachmentID,
      imageURL: nil,
      imageExpiresIn: nil,
      clientID: clientID,
      createdAt: createdAt
    )
    messages.append(message)
    messagesByConversationID[conversationID] = messages

    let conversation = conversations[conversationIndex]
    conversations[conversationIndex] = ChatConversation(
      id: conversation.id,
      otherPartyID: conversation.otherPartyID,
      otherPartyName: conversation.otherPartyName,
      lastMessagePreview: kind == .image ? "[图片]" : text.map { String($0.prefix(80)) },
      lastMessageAt: createdAt,
      unreadCount: unreadCount(in: conversationID, after: conversation.myLastRead?.seq ?? 0),
      myLastRead: conversation.myLastRead,
      otherLastRead: conversation.otherLastRead
    )
    return message
  }

  private func conversationForCurrentUser(_ conversation: ChatConversation) -> ChatConversation {
    replacing(
      conversation,
      unreadCount: unreadCount(
        in: conversation.id,
        after: conversation.myLastRead?.seq ?? 0
      ),
      myLastRead: conversation.myLastRead
    )
  }

  private func replacing(
    _ conversation: ChatConversation,
    unreadCount: Int,
    myLastRead: ChatCursor?
  ) -> ChatConversation {
    ChatConversation(
      id: conversation.id,
      otherPartyID: conversation.otherPartyID,
      otherPartyName: conversation.otherPartyName,
      lastMessagePreview: conversation.lastMessagePreview,
      lastMessageAt: conversation.lastMessageAt,
      unreadCount: unreadCount,
      myLastRead: myLastRead,
      otherLastRead: conversation.otherLastRead
    )
  }

  private func unreadCount(in conversationID: UUID, after seq: Int) -> Int {
    messagesByConversationID[conversationID, default: []]
      .filter { $0.senderID != currentUserID && $0.seq > seq }
      .count
  }

  private static func conversationOrder(
    _ lhs: ChatConversation,
    _ rhs: ChatConversation
  ) -> Bool {
    switch (lhs.lastMessageAt, rhs.lastMessageAt) {
    case (let left?, let right?) where left != right:
      return left > right
    case (_?, nil):
      return true
    case (nil, _?):
      return false
    default:
      return lhs.id.uuidString > rhs.id.uuidString
    }
  }
}
