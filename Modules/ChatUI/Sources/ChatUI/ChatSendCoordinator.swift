import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct ChatSendOperationKey: Hashable, Sendable {
  let conversationID: UUID
  let clientID: String
}

private enum ChatSendTaskContext {
  @TaskLocal static var operationKey: ChatSendOperationKey?
}

@Observable
@MainActor
public final class ChatSendCoordinator {
  public let currentUserID: UUID

  @ObservationIgnored private let repository: any ChatRepository
  @ObservationIgnored private let onBindingInvalidated: @Sendable () async -> Void
  private var outboxesByConversationID: [UUID: [ChatOutboxItem]] = [:]
  @ObservationIgnored private var tasks: [ChatSendOperationKey: Task<Void, Never>] = [:]
  @ObservationIgnored private var itemGenerations: [ChatSendOperationKey: UInt64] = [:]
  @ObservationIgnored var setRefOperations: [ChatSendOperationKey: SetRefSendOperation] =
    [:]
  @ObservationIgnored private var settledClientIDs: [UUID: Set<String>] = [:]
  @ObservationIgnored private var generation: UInt64 = 0
  @ObservationIgnored private var invalidationGeneration: UInt64?
  /// True while `cancelAllAndWaitForCleanup()` is draining; `enqueue` refuses
  /// new work for the duration so nothing outlives the cleanup.
  @ObservationIgnored private var isDraining = false

  public init(
    repository: any ChatRepository,
    currentUserID: UUID,
    onBindingInvalidated: @escaping @Sendable () async -> Void = {}
  ) {
    self.repository = repository
    self.currentUserID = currentUserID
    self.onBindingInvalidated = onBindingInvalidated
  }

  public func outbox(in conversationID: UUID) -> [ChatOutboxItem] {
    outboxesByConversationID[conversationID, default: []]
  }

  @discardableResult
  public func sendText(in conversationID: UUID, text: String) -> String {
    sendText(in: conversationID, text: text, clientID: Self.makeClientID())
  }

  @discardableResult
  public func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) -> String {
    enqueue(.text(text), in: conversationID, clientID: clientID)
  }

  @discardableResult
  public func sendImage(in conversationID: UUID, imageData: Data) -> String {
    sendImage(in: conversationID, imageData: imageData, clientID: Self.makeClientID())
  }

  @discardableResult
  public func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) -> String {
    enqueue(.image(imageData), in: conversationID, clientID: clientID)
  }

  public func retry(in conversationID: UUID, clientID: String) {
    // Same gate as `enqueue`: a retry during the drain would re-stamp the item
    // with the surviving generation, so the sweep would leave it behind — stuck
    // in `.sending` if the retry then cancels cooperatively.
    guard !isDraining else {
      return
    }

    guard
      let item = outboxesByConversationID[conversationID]?.first(where: {
        $0.clientID == clientID
      }),
      case .failed = item.state
    else {
      return
    }

    replaceState(of: item, with: .sending)
    let key = ChatSendOperationKey(conversationID: conversationID, clientID: clientID)
    itemGenerations[key] = generation
    start(item: replacingState(of: item, with: .sending), generation: generation)
  }

  public func acknowledgeConfirmed(in conversationID: UUID, clientID: String) {
    removeOutboxItem(in: conversationID, clientID: clientID, markSettled: true)
  }

  public func reconcile(in conversationID: UUID, with confirmedMessages: [ChatMessage]) {
    let matchingClientIDs = Set(
      confirmedMessages.lazy
        .filter { $0.conversationID == conversationID && $0.senderID == self.currentUserID }
        .map(\.clientID)
    )
    guard !matchingClientIDs.isEmpty else {
      return
    }

    for clientID in matchingClientIDs {
      guard
        outboxesByConversationID[conversationID]?.contains(where: {
          $0.clientID == clientID
        }) == true
      else {
        continue
      }
      removeOutboxItem(in: conversationID, clientID: clientID, markSettled: true)
    }
  }

  public func cancelAllAndWaitForCleanup() async {
    generation &+= 1
    invalidationGeneration = nil
    let survivingGeneration = generation
    let callerKey = ChatSendTaskContext.operationKey

    // Closed for new work until the drain finishes; see `enqueue`.
    isDraining = true
    defer { isDraining = false }

    // Drain in a loop rather than from one snapshot. Awaiting a task lets the
    // MainActor run other work, which can register further tasks; a single pass
    // would return while those are still live, leaving a logged-out session
    // still sending.
    while true {
      let pending = tasks.filter { key, _ in key != callerKey }
      if pending.isEmpty {
        break
      }
      for task in pending.values {
        task.cancel()
      }
      for task in pending.values {
        await task.value
      }
      for key in pending.keys {
        tasks[key] = nil
      }
    }

    removeItems(olderThan: survivingGeneration)
    settledClientIDs.removeAll()
  }

  func reportBindingInvalidation() {
    guard invalidationGeneration != generation else {
      return
    }
    invalidationGeneration = generation
    let callback = onBindingInvalidated
    Task {
      await callback()
    }
  }

  func enqueue(
    _ draft: PendingChatMessage,
    in conversationID: UUID,
    clientID: String,
    setRefOperation: SetRefSendOperation? = nil
  ) -> String {
    // A drain is not a moment, it is an interval: `cancelAllAndWaitForCleanup`
    // suspends, and the MainActor is re-entrant across those suspensions. Work
    // that lands mid-drain — most easily an image-preparation task finishing
    // during logout or a re-bind — would otherwise enqueue with the surviving
    // generation and outlive the very cleanup that was meant to remove it.
    guard !isDraining else {
      return clientID
    }

    let key = ChatSendOperationKey(conversationID: conversationID, clientID: clientID)
    if outboxesByConversationID[conversationID]?.contains(where: {
      $0.clientID == clientID
    }) == true {
      return clientID
    }

    settledClientIDs[conversationID]?.remove(clientID)
    let item = ChatOutboxItem(
      clientID: clientID,
      conversationID: conversationID,
      senderID: currentUserID,
      draft: draft,
      state: .sending
    )
    if let setRefOperation {
      setRefOperations[key] = setRefOperation
    }
    outboxesByConversationID[conversationID, default: []].append(item)
    itemGenerations[key] = generation
    start(item: item, generation: generation)
    return clientID
  }

  private func start(item: ChatOutboxItem, generation capturedGeneration: UInt64) {
    let key = ChatSendOperationKey(
      conversationID: item.conversationID,
      clientID: item.clientID
    )
    let task = Task { @MainActor [weak self] in
      await ChatSendTaskContext.$operationKey.withValue(key) {
        guard let self else {
          return
        }
        await self.performSend(item: item, generation: capturedGeneration)
      }
    }
    tasks[key] = task
  }

  private func performSend(item: ChatOutboxItem, generation capturedGeneration: UInt64) async {
    let key = ChatSendOperationKey(
      conversationID: item.conversationID,
      clientID: item.clientID
    )
    do {
      let message: ChatMessage
      if let operation = setRefOperations[key] {
        let videoID = try await resolveVideoID(for: operation, key: key)
        message = try await repository.sendSetRef(
          in: item.conversationID,
          body: operation.intent.body,
          setRef: operation.intent.setRef,
          videoID: videoID,
          clientID: item.clientID
        )
      } else {
        switch item.draft {
        case .text(let text):
          message = try await repository.sendText(
            in: item.conversationID,
            text: text,
            clientID: item.clientID
          )
        case .image(let imageData):
          message = try await repository.sendImage(
            in: item.conversationID,
            imageData: imageData,
            clientID: item.clientID
          )
        }
      }
      unregister(key)
      guard canApplyResult(for: key, generation: capturedGeneration) else {
        return
      }
      replaceState(of: item, with: .confirmed(message))
    } catch {
      unregister(key)
      guard canApplyResult(for: key, generation: capturedGeneration) else {
        return
      }
      if error.isChatTaskCancellation || Task.isCancelled {
        return
      }
      replaceState(of: item, with: .failed(error))
      if error as? ChatRepositoryError == .bindRequired {
        reportBindingInvalidation()
      }
    }
  }

  private func canApplyResult(
    for key: ChatSendOperationKey,
    generation capturedGeneration: UInt64
  ) -> Bool {
    capturedGeneration == generation
      && settledClientIDs[key.conversationID]?.contains(key.clientID) != true
      && itemGenerations[key] == capturedGeneration
  }

  private func unregister(_ key: ChatSendOperationKey) {
    tasks[key] = nil
  }

}

extension ChatSendCoordinator {
  fileprivate func replaceState(of item: ChatOutboxItem, with state: ChatSendState) {
    guard
      let index = outboxesByConversationID[item.conversationID]?.firstIndex(where: {
        $0.clientID == item.clientID
      })
    else {
      return
    }
    outboxesByConversationID[item.conversationID]?[index] = replacingState(
      of: item,
      with: state
    )
  }

  fileprivate func replacingState(of item: ChatOutboxItem, with state: ChatSendState)
    -> ChatOutboxItem
  {
    ChatOutboxItem(
      clientID: item.clientID,
      conversationID: item.conversationID,
      senderID: item.senderID,
      draft: item.draft,
      state: state
    )
  }

  fileprivate func removeOutboxItem(
    in conversationID: UUID,
    clientID: String,
    markSettled: Bool
  ) {
    outboxesByConversationID[conversationID]?.removeAll { $0.clientID == clientID }
    if outboxesByConversationID[conversationID]?.isEmpty == true {
      outboxesByConversationID[conversationID] = nil
    }
    let key = ChatSendOperationKey(conversationID: conversationID, clientID: clientID)
    itemGenerations[key] = nil
    setRefOperations[key] = nil
    if markSettled {
      settledClientIDs[conversationID, default: []].insert(clientID)
    }
  }

  fileprivate func removeItems(olderThan survivingGeneration: UInt64) {
    let staleKeys = itemGenerations.compactMap { key, itemGeneration in
      itemGeneration < survivingGeneration ? key : nil
    }
    for key in staleKeys {
      removeOutboxItem(
        in: key.conversationID,
        clientID: key.clientID,
        markSettled: false
      )
    }
  }

  static func makeClientID() -> String {
    "ios-\(UUID().uuidString.lowercased())"
  }
}
