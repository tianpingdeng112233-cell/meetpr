import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatInboxViewModelTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(40)

  @Test func applyReadStateAtomicallyUpdatesConversationAndTotal() async {
    let repository = TestChatRepository()
    await repository.setConversations([
      chatTestConversation(id: conversationID, unreadCount: 3),
      chatTestConversation(id: chatTestUUID(41), unreadCount: 2),
    ])
    let viewModel = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID
    )
    await viewModel.refresh()
    let cursor = ChatCursor(messageID: UUID(), seq: 8)

    viewModel.apply(
      ChatReadState(myLastRead: cursor, unreadCount: 0),
      for: conversationID
    )

    #expect(viewModel.conversations.first(where: { $0.id == conversationID })?.unreadCount == 0)
    #expect(viewModel.conversations.first(where: { $0.id == conversationID })?.myLastRead == cursor)
    #expect(viewModel.totalUnread == 2)
  }

  @Test func repeatedStartCreatesOneThirtySecondPoller() async {
    let repository = TestChatRepository()
    let sleeper = ManualChatSleeper()
    let viewModel = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID,
      sleep: { duration in try await sleeper.sleep(for: duration) }
    )

    viewModel.startPolling()
    viewModel.startPolling()
    let oneWaiter = await chatEventually { await sleeper.waiterCount() == 1 }
    #expect(oneWaiter)
    #expect(await sleeper.sleepCount == 1)

    await sleeper.resumeNext()
    let refreshed = await chatEventually { await repository.fetchConversationCount == 1 }
    #expect(refreshed)
    viewModel.stopPolling()
    let stopped = await chatEventually { await sleeper.waiterCount() == 0 }
    #expect(stopped)
  }

  @Test func staleRefreshResponseCannotOverwriteNewerSnapshot() async {
    let repository = StaleInboxRepository()
    let viewModel = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID
    )
    let oldConversation = chatTestConversation(id: conversationID, unreadCount: 5)
    let newConversation = chatTestConversation(id: conversationID, unreadCount: 1)

    let first = Task { @MainActor in await viewModel.refresh() }
    let firstWaiting = await chatEventually { await repository.pendingRequestIDs() == [1] }
    #expect(firstWaiting)
    let second = Task { @MainActor in await viewModel.refresh() }
    let bothWaiting = await chatEventually { await repository.pendingRequestIDs() == [1, 2] }
    #expect(bothWaiting)

    await repository.resolve(requestID: 2, conversations: [newConversation])
    await second.value
    await repository.resolve(requestID: 1, conversations: [oldConversation])
    await first.value

    #expect(viewModel.totalUnread == 1)
    #expect(viewModel.conversations.first?.unreadCount == 1)
  }
  @Test func refreshLandingAfterMarkReadCannotResurrectTheBadge() async {
    // The refresh generation only orders refresh against refresh. A refresh that
    // sampled the unread count *before* a mark-read would otherwise return
    // afterwards and write the stale count back, bringing a cleared badge back.
    let repository = StaleInboxRepository()
    let viewModel = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID
    )
    let unread = chatTestConversation(id: conversationID, unreadCount: 5)

    let inFlight = Task { @MainActor in await viewModel.refresh() }
    let waiting = await chatEventually { await repository.pendingRequestIDs() == [1] }
    #expect(waiting)

    viewModel.apply(
      ChatReadState(
        myLastRead: ChatCursor(messageID: chatTestUUID(90), seq: 9),
        unreadCount: 0
      ),
      for: conversationID
    )

    // The pre-mark-read snapshot arrives last and must be discarded.
    await repository.resolve(requestID: 1, conversations: [unread])
    await inFlight.value

    #expect(viewModel.totalUnread == 0)
  }
}

private actor StaleInboxRepository: ChatRepository {
  private var nextRequestID = 0
  private var continuations: [Int: CheckedContinuation<[ChatConversation], any Error>] = [:]

  func pendingRequestIDs() -> [Int] {
    continuations.keys.sorted()
  }

  func resolve(requestID: Int, conversations: [ChatConversation]) {
    continuations.removeValue(forKey: requestID)?.resume(returning: conversations)
  }

  func fetchConversations() async throws -> [ChatConversation] {
    nextRequestID += 1
    let requestID = nextRequestID
    return try await withCheckedThrowingContinuation { continuation in
      continuations[requestID] = continuation
    }
  }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    throw ChatRepositoryError.conversationNotFound
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
  }

  func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    throw ChatTestError.failed
  }

  func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    throw ChatTestError.failed
  }

  func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    throw ChatTestError.failed
  }
}
