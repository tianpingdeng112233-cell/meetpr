import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import ChatUI

@Suite @MainActor struct ChatSendCoordinatorCleanupTests {
  private let currentUserID = chatTestUUID(1)
  private let conversationID = chatTestUUID(10)

  @Test func cancellationGenerationDiscardsLateNonCooperativeResponse() async {
    let repository = TestChatRepository()
    await repository.suspendTextSends()
    let lateMessage = chatTestMessage(
      conversationID: conversationID,
      seq: 1,
      senderID: currentUserID,
      clientID: "late"
    )
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    coordinator.sendText(in: conversationID, text: "消息", clientID: "late")
    _ = await chatEventually { await repository.pendingTextClientIDs().contains("late") }

    let cancellation = Task { @MainActor in
      await coordinator.cancelAllAndWaitForCleanup()
    }
    let wasCancelled = await chatEventually {
      await repository.cancelledTextIDs().contains("late")
    }
    #expect(wasCancelled)
    await repository.resolveText(clientID: "late", with: .success(lateMessage))
    await cancellation.value

    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }

  @Test func sendEnqueuedDuringCleanupDoesNotOutliveIt() async {
    // The drain suspends, and the MainActor is re-entrant across those
    // suspensions, so work can arrive mid-cleanup — an image-preparation task
    // finishing during logout is the realistic case. Such a send must not
    // survive the cleanup that was meant to remove it.
    let repository = TestChatRepository()
    await repository.suspendTextSends()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    coordinator.sendText(in: conversationID, text: "第一条", clientID: "in-flight")
    _ = await chatEventually { await repository.pendingTextClientIDs().contains("in-flight") }

    let cleanup = Task { @MainActor in
      await coordinator.cancelAllAndWaitForCleanup()
    }
    _ = await chatEventually { await repository.cancelledTextIDs().contains("in-flight") }

    // Lands while the drain is parked awaiting the cancelled task.
    coordinator.sendText(in: conversationID, text: "清理途中", clientID: "mid-drain")

    await repository.resolveText(
      clientID: "in-flight",
      with: .success(
        chatTestMessage(
          conversationID: conversationID,
          seq: 1,
          senderID: currentUserID,
          clientID: "in-flight"
        )
      )
    )
    await cleanup.value

    #expect(coordinator.outbox(in: conversationID).isEmpty)
    #expect(await repository.pendingTextClientIDs().contains("mid-drain") == false)
  }

  @Test func cancelAllWaitsForImageCleanup() async {
    let repository = CleanupChatRepository()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID
    )
    coordinator.sendImage(
      in: conversationID,
      imageData: Data([1]),
      clientID: "image-cleanup"
    )
    let sendStarted = await chatEventually { await repository.sendStarted }
    #expect(sendStarted)

    let completion = ChatTestFlag()
    let cancellation = Task { @MainActor in
      await coordinator.cancelAllAndWaitForCleanup()
      await completion.set()
    }
    let cleanupStarted = await chatEventually { await repository.cleanupStarted }
    #expect(cleanupStarted)
    #expect(await completion.value == false)

    await repository.finishCleanup()
    await cancellation.value
    #expect(await repository.cleanupFinished)
    #expect(await completion.value)
    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }

  @Test func bindRequiredDoesNotSelfDeadlockAndCallbackFiresOnce() async {
    let repository = TestChatRepository()
    await repository.enqueueTextSend(.bindRequired)
    await repository.enqueueTextSend(.bindRequired)
    let holder = ChatCoordinatorHolder()
    let callbackCount = ChatTestCounter()
    let coordinator = ChatSendCoordinator(
      repository: repository,
      currentUserID: currentUserID,
      onBindingInvalidated: {
        await callbackCount.increment()
        await holder.cancelAll()
      }
    )
    holder.coordinator = coordinator

    coordinator.sendText(in: conversationID, text: "一", clientID: "bind-1")
    coordinator.sendText(in: conversationID, text: "二", clientID: "bind-2")
    let callbackCompleted = await chatEventually { await callbackCount.value == 1 }

    #expect(callbackCompleted)
    #expect(await callbackCount.value == 1)
    #expect(coordinator.outbox(in: conversationID).isEmpty)
  }
}

@MainActor
private final class ChatCoordinatorHolder {
  var coordinator: ChatSendCoordinator?

  func cancelAll() async {
    await coordinator?.cancelAllAndWaitForCleanup()
  }
}

private actor ChatTestCounter {
  private(set) var value = 0

  func increment() {
    value += 1
  }
}

private actor ChatTestFlag {
  private(set) var value = false

  func set() {
    value = true
  }
}

private actor CleanupChatRepository: ChatRepository {
  private(set) var sendStarted = false
  private(set) var cleanupStarted = false
  private(set) var cleanupFinished = false
  private var cleanupContinuation: CheckedContinuation<Void, Never>?

  func fetchConversations() async throws -> [ChatConversation] { [] }

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
    sendStarted = true
    do {
      try await Task.sleep(for: .seconds(3_600))
      throw ChatTestError.failed
    } catch {
      cleanupStarted = true
      await withCheckedContinuation { continuation in
        cleanupContinuation = continuation
      }
      cleanupFinished = true
      throw CancellationError()
    }
  }

  func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    throw ChatTestError.failed
  }

  func finishCleanup() {
    cleanupContinuation?.resume()
    cleanupContinuation = nil
  }
}
