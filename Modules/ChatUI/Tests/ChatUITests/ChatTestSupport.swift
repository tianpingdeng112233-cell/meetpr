import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

private typealias VoidThrowingContinuation = CheckedContinuation<Void, any Error>

enum ChatTestError: Error, Equatable, Sendable {
  case failed
}

enum PlannedChatSend: Sendable {
  case message(ChatMessage)
  case failure
  case bindRequired
}

actor TestChatRepository: ChatRepository {
  private var conversations: [ChatConversation] = []
  private var pageResults: [Result<ChatMessagePage, ChatTestError>] = []
  private var plannedTextSends: [PlannedChatSend] = []
  private var plannedImageSends: [PlannedChatSend] = []
  private var suspendedTextSends = false
  private var pendingTextContinuations: [String: CheckedContinuation<ChatMessage, any Error>] = [:]
  private var cancelledTextClientIDs: Set<String> = []
  private var knownMessagesByID: [UUID: ChatMessage] = [:]
  private var automaticSequence = 0

  private(set) var fetchConversationCount = 0
  private(set) var queries: [ChatMessageQuery] = []
  private(set) var textClientIDs: [String] = []
  private(set) var textBodies: [String] = []
  private(set) var imageClientIDs: [String] = []
  private(set) var readMessageIDs: [UUID] = []

  func setConversations(_ conversations: [ChatConversation]) {
    self.conversations = conversations
  }

  func enqueuePage(_ page: ChatMessagePage) {
    pageResults.append(.success(page))
    for message in page.messages {
      knownMessagesByID[message.id] = message
    }
  }

  func enqueuePageFailure() {
    pageResults.append(.failure(.failed))
  }

  func enqueueTextSend(_ send: PlannedChatSend) {
    plannedTextSends.append(send)
  }

  func enqueueImageSend(_ send: PlannedChatSend) {
    plannedImageSends.append(send)
  }

  func suspendTextSends() {
    suspendedTextSends = true
  }

  func pendingTextClientIDs() -> Set<String> {
    Set(pendingTextContinuations.keys)
  }

  func cancelledTextIDs() -> Set<String> {
    cancelledTextClientIDs
  }

  func resolveText(clientID: String, with result: Result<ChatMessage, ChatTestError>) {
    guard let continuation = pendingTextContinuations.removeValue(forKey: clientID) else {
      return
    }
    switch result {
    case .success(let message):
      continuation.resume(returning: message)
    case .failure(let error):
      continuation.resume(throwing: error)
    }
  }

  func fetchConversations() async throws -> [ChatConversation] {
    fetchConversationCount += 1
    return conversations
  }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    if let conversation = conversations.first(where: { $0.otherPartyID == otherPartyID }) {
      return conversation
    }
    throw ChatRepositoryError.conversationNotFound
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    queries.append(query)
    guard !pageResults.isEmpty else {
      return ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    }
    return try pageResults.removeFirst().get()
  }

  func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    textClientIDs.append(clientID)
    textBodies.append(text)
    if suspendedTextSends {
      return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          pendingTextContinuations[clientID] = continuation
        }
      } onCancel: {
        Task {
          await self.recordTextCancellation(clientID: clientID)
        }
      }
    }
    if !plannedTextSends.isEmpty {
      return try resolve(plannedTextSends.removeFirst())
    }
    automaticSequence += 1
    return chatTestMessage(
      conversationID: conversationID,
      seq: automaticSequence,
      senderID: chatTestUUID(1),
      clientID: clientID,
      text: text
    )
  }

  func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    imageClientIDs.append(clientID)
    if !plannedImageSends.isEmpty {
      return try resolve(plannedImageSends.removeFirst())
    }
    automaticSequence += 1
    return chatTestMessage(
      conversationID: conversationID,
      seq: automaticSequence,
      senderID: chatTestUUID(1),
      clientID: clientID,
      kind: .image
    )
  }

  func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    readMessageIDs.append(messageID)
    guard let message = knownMessagesByID[messageID] else {
      throw ChatTestError.failed
    }
    return ChatReadState(
      myLastRead: ChatCursor(messageID: message.id, seq: message.seq),
      unreadCount: 0
    )
  }

  private func resolve(_ send: PlannedChatSend) throws -> ChatMessage {
    switch send {
    case .message(let message):
      return message
    case .failure:
      throw ChatTestError.failed
    case .bindRequired:
      throw ChatRepositoryError.bindRequired
    }
  }

  private func recordTextCancellation(clientID: String) {
    cancelledTextClientIDs.insert(clientID)
  }
}

actor ManualChatSleeper {
  private var continuations: [UUID: CheckedContinuation<Void, any Error>] = [:]
  private var order: [UUID] = []
  private var cancelledIDs: Set<UUID> = []
  private(set) var sleepCount = 0

  func sleep(for duration: Duration) async throws {
    let id = UUID()
    sleepCount += 1
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: VoidThrowingContinuation) in
        if cancelledIDs.remove(id) != nil {
          continuation.resume(throwing: CancellationError())
        } else {
          continuations[id] = continuation
          order.append(id)
        }
      }
    } onCancel: {
      Task {
        await self.cancel(id)
      }
    }
  }

  func resumeNext() {
    guard !order.isEmpty else {
      return
    }
    let id = order.removeFirst()
    continuations.removeValue(forKey: id)?.resume()
  }

  func waiterCount() -> Int {
    continuations.count
  }

  private func cancel(_ id: UUID) {
    if let continuation = continuations.removeValue(forKey: id) {
      order.removeAll { $0 == id }
      continuation.resume(throwing: CancellationError())
    } else {
      cancelledIDs.insert(id)
    }
  }
}

final class LockedTestNow: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) {
    self.value = value
  }

  func callAsFunction() -> Date {
    lock.withLock { value }
  }

  func advance(by interval: TimeInterval) {
    lock.withLock {
      value = value.addingTimeInterval(interval)
    }
  }
}

func chatTestMessage(
  id: UUID = UUID(),
  conversationID: UUID,
  seq: Int,
  senderID: UUID,
  clientID: String,
  kind: ChatMessageKind = .text,
  text: String? = "消息",
  imageURL: URL? = nil,
  imageExpiresIn: Int? = nil
) -> ChatMessage {
  ChatMessage(
    id: id,
    conversationID: conversationID,
    seq: seq,
    senderID: senderID,
    kind: kind,
    text: kind == .text ? text : nil,
    attachmentID: kind == .image ? UUID() : nil,
    imageURL: imageURL,
    imageExpiresIn: imageExpiresIn,
    clientID: clientID,
    createdAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + seq))
  )
}

func chatTestConversation(
  id: UUID,
  unreadCount: Int,
  myLastRead: ChatCursor? = nil
) -> ChatConversation {
  ChatConversation(
    id: id,
    otherPartyID: chatTestUUID(2),
    otherPartyName: "对方",
    lastMessagePreview: "消息",
    lastMessageAt: Date(timeIntervalSince1970: 1_700_000_000),
    unreadCount: unreadCount,
    myLastRead: myLastRead,
    otherLastRead: nil
  )
}

func chatTestUUID(_ suffix: UInt8) -> UUID {
  UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x5A, suffix))
}

@MainActor
func chatEventually(
  attempts: Int = 1_000,
  _ condition: @escaping @MainActor () async -> Bool
) async -> Bool {
  for _ in 0..<attempts {
    if await condition() {
      return true
    }
    await Task.yield()
  }
  return false
}
