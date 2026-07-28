import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ConversationViewModelTests {
  private let currentUserID = chatTestUUID(1)
  private let otherUserID = chatTestUUID(2)
  private let conversationID = chatTestUUID(20)

  @Test func repeatedPollingStartHasOneOwnerAndCancellationIsNotAnError() async {
    let repository = TestChatRepository()
    let sleeper = ManualChatSleeper()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator,
      sleep: { duration in try await sleeper.sleep(for: duration) }
    )

    let firstPoller = Task { @MainActor in await viewModel.pollUntilCancelled() }
    let secondPoller = Task { @MainActor in await viewModel.pollUntilCancelled() }
    let oneSleeper = await chatEventually { await sleeper.waiterCount() == 1 }
    #expect(oneSleeper)
    #expect(await sleeper.sleepCount == 1)

    await sleeper.resumeNext()
    let didPoll = await chatEventually { await repository.queries.count == 1 }
    #expect(didPoll)
    firstPoller.cancel()
    secondPoller.cancel()
    await firstPoller.value
    await secondPoller.value

    #expect(viewModel.error == nil)
    #expect(viewModel.isPolling == false)
  }

  @Test func catchUpStopsWhenSequenceDoesNotAdvance() async {
    let repository = TestChatRepository()
    let message = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "one"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [message], otherLastRead: nil, hasMore: false)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [message], otherLastRead: nil, hasMore: true)
    )
    let viewModel = makeViewModel(repository: repository)
    await viewModel.load()

    await viewModel.pollOnce()

    #expect(await repository.queries.count == 2)
    #expect(viewModel.messages.map(\.seq) == [1])
  }

  @Test func emptyConversationUsesLatestThenSwitchesToAfterMaximumSequence() async {
    let repository = TestChatRepository()
    let first = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "first"
    )
    // hasMore on the latest page means *older* history exists; it must not be
    // mistaken for more to catch up forward within the same tick.
    await repository.enqueuePage(
      ChatMessagePage(messages: [first], otherLastRead: nil, hasMore: true)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)

    await viewModel.pollOnce()
    #expect(await repository.queries.map(\.mode) == [.latest])
    #expect(viewModel.hasMoreHistory)

    await viewModel.pollOnce()
    #expect(await repository.queries.map(\.mode) == [.latest, .after(seq: 1)])
  }

  @Test func emptyConversationFinishesInitialLoadOnlyAfterSuccessfulFetch() async {
    let repository = TestChatRepository()
    await repository.enqueuePage(
      ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)

    #expect(!viewModel.didFinishInitialLoad)
    await viewModel.load()

    #expect(viewModel.didFinishInitialLoad)
    #expect(viewModel.error == nil)
    #expect(viewModel.renderedMessages.isEmpty)
  }

  @Test func failedInitialConversationLoadStaysOutOfTheEmptyState() async {
    let repository = TestChatRepository()
    await repository.enqueuePageFailure()
    let viewModel = makeViewModel(repository: repository)

    await viewModel.load()

    #expect(!viewModel.didFinishInitialLoad)
    #expect(viewModel.error != nil)
    #expect(viewModel.renderedMessages.isEmpty)
  }

  @Test func successfulEmptyPollRecoversFailedInitialLoadIntoEmptyState() async {
    let repository = TestChatRepository()
    await repository.enqueuePageFailure()
    await repository.enqueuePage(
      ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)

    await viewModel.load()
    #expect(!viewModel.didFinishInitialLoad)
    #expect(viewModel.error != nil)

    await viewModel.pollOnce()

    #expect(viewModel.didFinishInitialLoad)
    #expect(viewModel.error == nil)
    #expect(viewModel.renderedMessages.isEmpty)
    #expect(await repository.queries.map(\.mode) == [.latest, .latest])
  }

  @Test func historyPrependDeduplicatesAndPreservesSequenceOrder() async {
    let repository = TestChatRepository()
    let third = chatTestMessage(
      conversationID: conversationID,
      seq: 3,
      senderID: currentUserID,
      clientID: "three"
    )
    let fourth = chatTestMessage(
      conversationID: conversationID,
      seq: 4,
      senderID: currentUserID,
      clientID: "four"
    )
    let second = chatTestMessage(
      conversationID: conversationID,
      seq: 2,
      senderID: currentUserID,
      clientID: "two"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [fourth, third], otherLastRead: nil, hasMore: true)
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [third, second], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeViewModel(repository: repository)

    await viewModel.load()
    await viewModel.loadOlder()

    #expect(viewModel.messages.map(\.seq) == [2, 3, 4])
    #expect(Set(viewModel.messages.map(\.id)).count == 3)
    #expect(await repository.queries.map(\.mode) == [.latest, .before(seq: 3)])
  }

  @Test func textSendTrimsWhitespaceAndRejectsEmptyOrOversizedInput() async {
    let repository = TestChatRepository()
    let viewModel = makeViewModel(repository: repository)

    #expect(viewModel.sendText("  \n") == nil)
    #expect(
      viewModel.sendText(String(repeating: "字", count: ConversationViewModel.maximumTextLength + 1))
        == nil
    )
    #expect(viewModel.sendText("  有效消息  ") != nil)
    let sent = await chatEventually { await repository.textBodies == ["有效消息"] }

    #expect(sent)
    #expect(await repository.textClientIDs.count == 1)
  }

  @Test func readReceiptUsesInclusiveSequenceBoundary() async {
    for readSequence in [9, 10, 11] {
      let repository = TestChatRepository()
      let outgoing = chatTestMessage(
        conversationID: conversationID,
        seq: 10,
        senderID: currentUserID,
        clientID: "outgoing"
      )
      await repository.enqueuePage(
        ChatMessagePage(
          messages: [outgoing],
          otherLastRead: ChatCursor(messageID: UUID(), seq: readSequence),
          hasMore: false
        )
      )
      let viewModel = makeViewModel(repository: repository)
      await viewModel.load()

      let expected: ChatDeliveryStatus = readSequence >= 10 ? .read : .delivered
      #expect(viewModel.deliveryStatus(for: outgoing) == expected)
    }
  }

  @Test func staleMarkReadResponseCannotOverwriteNewerInboxState() async {
    let repository = StaleReadChatRepository(
      pages: [
        incomingPage(sequence: 1),
        incomingPage(sequence: 2),
      ]
    )
    let inboxRepository = TestChatRepository()
    await inboxRepository.setConversations([
      chatTestConversation(id: conversationID, unreadCount: 2)
    ])
    let inbox = ChatInboxViewModel(
      repository: inboxRepository,
      currentUserID: currentUserID
    )
    await inbox.refresh()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    let viewModel = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator,
      inbox: inbox
    )

    let firstPoll = Task { @MainActor in await viewModel.pollOnce() }
    let firstReadWaiting = await chatEventually { await repository.pendingReadSequences() == [1] }
    #expect(firstReadWaiting)
    let secondPoll = Task { @MainActor in await viewModel.pollOnce() }
    let bothReadsWaiting = await chatEventually {
      await repository.pendingReadSequences() == [1, 2]
    }
    #expect(bothReadsWaiting)

    await repository.resolveRead(sequence: 2, unreadCount: 0)
    await secondPoll.value
    await repository.resolveRead(sequence: 1, unreadCount: 1)
    await firstPoll.value

    #expect(inbox.conversations.first?.myLastRead?.seq == 2)
    #expect(inbox.totalUnread == 0)
  }

  private func makeViewModel(repository: TestChatRepository) -> ConversationViewModel {
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    return ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: coordinator
    )
  }

  private func incomingPage(sequence: Int) -> ChatMessagePage {
    ChatMessagePage(
      messages: [
        chatTestMessage(
          conversationID: conversationID,
          seq: sequence,
          senderID: otherUserID,
          clientID: "incoming-\(sequence)"
        )
      ],
      otherLastRead: nil,
      hasMore: false
    )
  }
}

private actor StaleReadChatRepository: ChatRepository {
  private var pages: [ChatMessagePage]
  private var messagesByID: [UUID: ChatMessage]
  private var continuationsBySequence: [Int: CheckedContinuation<ChatReadState, any Error>] = [:]

  init(pages: [ChatMessagePage]) {
    self.pages = pages
    messagesByID = Dictionary(
      uniqueKeysWithValues: pages.flatMap(\.messages).map { ($0.id, $0) }
    )
  }

  func pendingReadSequences() -> [Int] {
    continuationsBySequence.keys.sorted()
  }

  func resolveRead(sequence: Int, unreadCount: Int) {
    guard
      let continuation = continuationsBySequence.removeValue(forKey: sequence),
      let message = messagesByID.values.first(where: { $0.seq == sequence })
    else {
      return
    }
    continuation.resume(
      returning: ChatReadState(
        myLastRead: ChatCursor(messageID: message.id, seq: sequence),
        unreadCount: unreadCount
      )
    )
  }

  func fetchConversations() async throws -> [ChatConversation] { [] }

  func openConversation(withOtherParty otherPartyID: UUID) async throws -> ChatConversation {
    throw ChatRepositoryError.conversationNotFound
  }

  func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    guard !pages.isEmpty else {
      return ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    }
    return pages.removeFirst()
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
    guard let sequence = messagesByID[messageID]?.seq else {
      throw ChatTestError.failed
    }
    return try await withCheckedThrowingContinuation { continuation in
      continuationsBySequence[sequence] = continuation
    }
  }
}
