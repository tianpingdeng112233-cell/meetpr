import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatRealtimeTests {
  private let currentUserID = chatTestUUID(1)
  private let otherUserID = chatTestUUID(2)
  private let conversationID = chatTestUUID(66)

  @Test func routerBroadcastsOneSourceEventToIndependentSubscribers() async {
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
    let router = ChatRealtimeRouter(events: eventSource.stream, state: stateSource.stream)
    let first = router.subscribe()
    let second = router.subscribe()
    let firstRecorder = RealtimeEventRecorder(stream: first.events)
    let secondRecorder = RealtimeEventRecorder(stream: second.events)
    let event = RealtimeEvent.chatMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: otherUserID
    )

    eventSource.yield(event)

    #expect(await chatEventually { await firstRecorder.events == [event] })
    #expect(await chatEventually { await secondRecorder.events == [event] })
    router.stop()
  }

  @Test func inboxSuspendsPollingWhileConnectedAndRestoresItWhenDisconnected() async {
    let repository = TestChatRepository()
    let sleeper = ManualChatSleeper()
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
    let viewModel = ChatInboxViewModel(
      repository: repository,
      currentUserID: currentUserID,
      sleep: { duration in try await sleeper.sleep(for: duration) }
    )
    viewModel.attachRealtime(events: eventSource.stream, state: stateSource.stream)
    stateSource.yield(.connected)
    #expect(await chatEventually { viewModel.isRealtimeConnected })

    viewModel.startPolling()
    for _ in 0..<20 { await Task.yield() }
    #expect(await sleeper.sleepCount == 0)

    eventSource.yield(
      .chatMessage(conversationID: conversationID, seq: 1, senderID: otherUserID)
    )
    #expect(await chatEventually { await repository.fetchConversationCount == 1 })

    stateSource.yield(.disconnected)
    #expect(await chatEventually { await sleeper.waiterCount() == 1 })
    #expect(await sleeper.sleepCount == 1)
    viewModel.stopPolling()
  }

  @Test func conversationFiltersEventsAndCoalescesDenseRefreshes() async {
    let repository = TestChatRepository()
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
    let viewModel = makeConversation(repository: repository)
    viewModel.attachRealtime(events: eventSource.stream, state: stateSource.stream)
    stateSource.yield(.connected)
    #expect(await chatEventually { viewModel.isRealtimeConnected })

    eventSource.yield(
      .chatMessage(conversationID: chatTestUUID(65), seq: 1, senderID: otherUserID)
    )
    for _ in 0..<20 { await Task.yield() }
    #expect(await repository.queries.isEmpty)

    await repository.suspendNextFetch()
    for sequence in 1...3 {
      eventSource.yield(
        .chatMessage(
          conversationID: conversationID,
          seq: sequence,
          senderID: otherUserID
        )
      )
    }
    #expect(await chatEventually { await repository.hasPendingFetch() })
    #expect(await repository.queries.count == 1)

    await repository.resolvePendingFetch(
      with: ChatMessagePage(messages: [], otherLastRead: nil, hasMore: false)
    )
    #expect(await chatEventually { await repository.queries.count == 2 })
    #expect(await repository.queries.allSatisfy { $0.mode == .latest })
  }

  @Test func conversationConnectedStateSuspendsThreeSecondPolling() async {
    let repository = TestChatRepository()
    let sleeper = ManualChatSleeper()
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
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
    viewModel.attachRealtime(events: eventSource.stream, state: stateSource.stream)
    stateSource.yield(.connected)
    #expect(await chatEventually { viewModel.isRealtimeConnected })

    let polling = Task { @MainActor in await viewModel.pollUntilCancelled() }
    for _ in 0..<20 { await Task.yield() }
    #expect(await sleeper.sleepCount == 0)

    stateSource.yield(.disconnected)
    #expect(await chatEventually { await sleeper.waiterCount() == 1 })
    #expect(await sleeper.sleepCount == 1)
    polling.cancel()
    await polling.value
  }

  @Test func chatReadAdvancesReceiptWithoutGoingBackwards() async {
    let repository = TestChatRepository()
    let message = chatTestMessage(
      conversationID: conversationID,
      seq: 4,
      senderID: currentUserID,
      clientID: "sent"
    )
    await repository.enqueuePage(
      ChatMessagePage(messages: [message], otherLastRead: nil, hasMore: false)
    )
    let viewModel = makeConversation(repository: repository)
    await viewModel.load()
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
    viewModel.attachRealtime(events: eventSource.stream, state: stateSource.stream)

    eventSource.yield(
      .chatRead(conversationID: conversationID, userID: otherUserID, lastReadSeq: 4)
    )
    #expect(await chatEventually { viewModel.otherLastRead?.seq == 4 })
    eventSource.yield(
      .chatRead(conversationID: conversationID, userID: otherUserID, lastReadSeq: 3)
    )
    for _ in 0..<20 { await Task.yield() }
    #expect(viewModel.otherLastRead?.seq == 4)
  }

  @Test func deallocatedConversationReleasesItsRouterSubscriptions() async {
    let repository = TestChatRepository()
    let eventSource = TestStreamSource<RealtimeEvent>()
    let stateSource = TestStreamSource<RealtimeConnectionState>()
    let inbox = ChatInboxViewModel(repository: repository, currentUserID: currentUserID)
    inbox.attachRealtime(events: eventSource.stream, state: stateSource.stream)
    let inboxOnly = inbox.realtimeSubscriberCount

    var conversation: ConversationViewModel? = ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: ChatSendCoordinator(
        repository: repository,
        currentUserID: currentUserID
      ),
      inbox: inbox
    )
    #expect(conversation != nil)
    #expect((inbox.realtimeSubscriberCount ?? 0) > (inboxOnly ?? 0))

    conversation = nil
    #expect(await chatEventually { inbox.realtimeSubscriberCount == inboxOnly })
    inbox.clear()
  }

  private func makeConversation(repository: TestChatRepository) -> ConversationViewModel {
    ConversationViewModel(
      conversationID: conversationID,
      currentUserID: currentUserID,
      repository: repository,
      sendCoordinator: ChatSendCoordinator(
        repository: repository,
        currentUserID: currentUserID
      )
    )
  }
}

private final class TestStreamSource<Element: Sendable>: @unchecked Sendable {
  let stream: AsyncStream<Element>
  private let continuation: AsyncStream<Element>.Continuation

  init() {
    var installedContinuation: AsyncStream<Element>.Continuation?
    stream = AsyncStream { installedContinuation = $0 }
    guard let installedContinuation else {
      preconditionFailure("Test stream continuation was not installed.")
    }
    continuation = installedContinuation
  }

  func yield(_ value: Element) {
    continuation.yield(value)
  }
}

private actor RealtimeEventRecorder {
  private(set) var events: [RealtimeEvent] = []

  init(stream: AsyncStream<RealtimeEvent>) {
    Task { [weak self] in
      for await event in stream {
        await self?.record(event)
      }
    }
  }

  private func record(_ event: RealtimeEvent) {
    events.append(event)
  }
}
