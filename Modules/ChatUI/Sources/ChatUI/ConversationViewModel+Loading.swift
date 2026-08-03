import CoreModels
import Foundation
import Networking
import Observation
import RepositoryContracts

@MainActor
extension ConversationViewModel {
  public func load() async {
    guard !isLoading else {
      return
    }
    isLoading = true
    defer { isLoading = false }
    do {
      let query = try ChatMessageQuery.latest(limit: pageLimit)
      let page = try await repository.fetchMessages(in: conversationID, query: query)
      merge(page.messages, obtainedAt: now())
      updateOtherLastRead(page.otherLastRead)
      hasMoreHistory = page.hasMore
      synchronizeOutbox()
      error = nil
      didFinishInitialLoad = true
      bindingInvalidationReported = false
      await markReadIfNeeded(from: page.messages)
    } catch {
      handle(error)
    }
  }

  public func loadOlder() async {
    guard !isLoadingOlder, hasMoreHistory, let firstSequence = messages.first?.seq else {
      return
    }
    isLoadingOlder = true
    defer { isLoadingOlder = false }
    do {
      let query = try ChatMessageQuery.before(seq: firstSequence, limit: pageLimit)
      let page = try await repository.fetchMessages(in: conversationID, query: query)
      merge(page.messages, obtainedAt: now())
      updateOtherLastRead(page.otherLastRead)
      hasMoreHistory = page.hasMore
      synchronizeOutbox()
      error = nil
      bindingInvalidationReported = false
    } catch {
      handle(error)
    }
  }

  public func pollUntilCancelled() async {
    guard !isPolling else {
      return
    }
    isPolling = true
    let ownerID = UUID()
    pollingOwnerID = ownerID
    startPollingWorkerIfNeeded()

    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if Task.isCancelled || pollingOwnerID != ownerID {
          continuation.resume()
        } else {
          pollingLifetimeContinuation = continuation
        }
      }
    } onCancel: {
      Task { @MainActor [weak self] in
        self?.finishPolling(ownerID: ownerID)
      }
    }
    finishPolling(ownerID: ownerID)
  }

  public func pollOnce() async {
    do {
      try await pollTick()
      error = nil
      bindingInvalidationReported = false
    } catch {
      handle(error)
    }
  }

  public func attachRealtime(
    events: AsyncStream<RealtimeEvent>,
    state: AsyncStream<RealtimeConnectionState>
  ) {
    realtimeEventTask?.cancel()
    realtimeStateTask?.cancel()
    realtimeRefreshTask?.cancel()
    realtimeRefreshPending = false

    // `guard let self else return` (not `self?`) so a deallocated view model
    // terminates the iteration, which releases the router continuation via
    // its onTermination hook instead of holding it for the session lifetime.
    realtimeEventTask = Task { @MainActor [weak self] in
      for await event in events {
        guard let self else { return }
        self.handleRealtime(event)
      }
    }
    realtimeStateTask = Task { @MainActor [weak self] in
      for await state in state {
        guard let self else { return }
        self.handleRealtime(state)
      }
    }
  }

  public func detachRealtime() {
    realtimeEventTask?.cancel()
    realtimeStateTask?.cancel()
    realtimeRefreshTask?.cancel()
    realtimeEventTask = nil
    realtimeStateTask = nil
    realtimeRefreshTask = nil
    realtimeRefreshPending = false
    // Without realtime this conversation is back on the polling contract; an
    // active view must regain its 3s fallback instead of losing both paths.
    isRealtimeConnected = false
    startPollingWorkerIfNeeded()
  }

  func synchronizeOutbox() {
    let items = sendCoordinator.outbox(in: conversationID)
    for item in items {
      guard case .confirmed(let message) = item.state else {
        continue
      }
      merge([message], obtainedAt: now())
      sendCoordinator.acknowledgeConfirmed(
        in: conversationID,
        clientID: item.clientID
      )
    }
    sendCoordinator.reconcile(in: conversationID, with: messages)
  }

  func observeOutbox() {
    withObservationTracking {
      _ = sendCoordinator.outbox(in: conversationID)
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else {
          return
        }
        self.synchronizeOutbox()
        self.observeOutbox()
      }
    }
  }

  func handle(_ error: any Error) {
    guard !error.isChatTaskCancellation else {
      return
    }
    self.error = error
    if error as? ChatRepositoryError == .bindRequired, !bindingInvalidationReported {
      bindingInvalidationReported = true
      sendCoordinator.reportBindingInvalidation()
    }
  }

  private func startPollingWorkerIfNeeded() {
    guard isPolling, !isRealtimeConnected, pollingWorker == nil else { return }
    pollingGeneration &+= 1
    let generation = pollingGeneration
    pollingWorker = Task { @MainActor [weak self] in
      await self?.runPollingWorker(generation: generation)
    }
  }

  private func suspendPollingWorker() {
    pollingGeneration &+= 1
    pollingWorker?.cancel()
    pollingWorker = nil
  }

  private func finishPolling(ownerID: UUID) {
    guard pollingOwnerID == ownerID else { return }
    pollingOwnerID = nil
    isPolling = false
    suspendPollingWorker()
    let continuation = pollingLifetimeContinuation
    pollingLifetimeContinuation = nil
    continuation?.resume()
  }

  private func runPollingWorker(generation: UInt64) async {
    defer {
      if generation == pollingGeneration {
        pollingWorker = nil
      }
    }
    while !Task.isCancelled, generation == pollingGeneration {
      do {
        try await sleep(.seconds(3))
        guard
          !Task.isCancelled,
          generation == pollingGeneration,
          !isRealtimeConnected
        else { return }
        try await pollTick()
        error = nil
        bindingInvalidationReported = false
      } catch {
        if error.isChatTaskCancellation || Task.isCancelled {
          return
        }
        handle(error)
      }
    }
  }

  private func handleRealtime(_ state: RealtimeConnectionState) {
    switch state {
    case .connected:
      isRealtimeConnected = true
      suspendPollingWorker()
    case .disconnected:
      isRealtimeConnected = false
      startPollingWorkerIfNeeded()
    }
  }

  private func handleRealtime(_ event: RealtimeEvent) {
    switch event {
    case .hello:
      break
    case .chatMessage(let conversationID, _, _):
      guard conversationID == self.conversationID else { return }
      scheduleRealtimeRefresh()
    case .chatRead(let conversationID, let userID, let lastReadSeq):
      guard conversationID == self.conversationID, userID != currentUserID else { return }
      guard lastReadSeq > (otherLastRead?.seq ?? 0) else { return }
      if let message = messages.first(where: { $0.seq == lastReadSeq }) {
        updateOtherLastRead(ChatCursor(messageID: message.id, seq: lastReadSeq))
      } else {
        scheduleRealtimeRefresh()
      }
    }
  }

  private func scheduleRealtimeRefresh() {
    if realtimeRefreshTask != nil {
      realtimeRefreshPending = true
      return
    }
    realtimeRefreshTask = Task { @MainActor [weak self] in
      guard let self else { return }
      repeat {
        realtimeRefreshPending = false
        await pollOnce()
      } while realtimeRefreshPending && !Task.isCancelled
      realtimeRefreshTask = nil
    }
  }

  private func pollTick() async throws {
    var query: ChatMessageQuery
    // A tick with nothing local has to bootstrap from the newest page; only
    // after that does polling mean "everything newer than what I hold".
    let isBootstrappingFromLatest = messages.last?.seq == nil
    if let maximumSequence = messages.last?.seq {
      query = try .after(seq: maximumSequence, limit: pageLimit)
    } else {
      query = try .latest(limit: pageLimit)
    }

    var incomingMessages: [ChatMessage] = []
    while true {
      let previousMaximum = messages.last?.seq
      let page = try await repository.fetchMessages(in: conversationID, query: query)
      incomingMessages.append(contentsOf: page.messages)
      merge(page.messages, obtainedAt: now())
      updateOtherLastRead(page.otherLastRead)
      synchronizeOutbox()

      if isBootstrappingFromLatest {
        // On a latest page `hasMore` means older history exists — the opposite
        // direction from this loop. Record it so loadOlder stays available (an
        // initial load that failed would otherwise leave history unpageable),
        // and let the next tick poll forward from the max seq just learned.
        hasMoreHistory = page.hasMore
        break
      }

      guard page.hasMore else {
        break
      }
      guard
        let nextSequence = messages.last?.seq,
        previousMaximum == nil || nextSequence > (previousMaximum ?? 0)
      else {
        break
      }
      query = try .after(seq: nextSequence, limit: pageLimit)
    }
    didFinishInitialLoad = true
    await markReadIfNeeded(from: incomingMessages)
  }

  private func merge(_ incoming: [ChatMessage], obtainedAt: Date) {
    var bySequence = Dictionary(uniqueKeysWithValues: messages.map { ($0.seq, $0) })
    for message in incoming
    where message.conversationID == conversationID && !removedMessageIDs.contains(message.id) {
      let existing = bySequence[message.seq]
      bySequence[message.seq] = message
      if message.kind == .image, message.imageURL != nil,
        existing?.imageURL != message.imageURL || imageURLObtainedAt[message.id] == nil
      {
        imageURLObtainedAt[message.id] = obtainedAt
      }
      if message.setRef != nil, message.videoURL != nil,
        existing?.videoURL != message.videoURL || videoURLObtainedAt[message.id] == nil
      {
        videoURLObtainedAt[message.id] = obtainedAt
      }
    }
    messages = bySequence.values.sorted { $0.seq < $1.seq }
    sendCoordinator.reconcile(in: conversationID, with: incoming)
  }

  func updateOtherLastRead(_ cursor: ChatCursor?) {
    guard let cursor, cursor.seq >= (otherLastRead?.seq ?? 0) else {
      return
    }
    otherLastRead = cursor
  }

  private func markReadIfNeeded(from incoming: [ChatMessage]) async {
    guard
      let target =
        incoming
        .filter({ $0.senderID != currentUserID })
        .max(by: { $0.seq < $1.seq }),
      target.seq > latestRequestedReadSequence
    else {
      return
    }

    latestRequestedReadSequence = target.seq
    readRequest &+= 1
    let request = readRequest
    do {
      let readState = try await repository.markRead(
        in: conversationID,
        upTo: target.id
      )
      guard
        request == readRequest,
        readState.myLastRead.seq >= latestAppliedReadSequence
      else {
        return
      }
      latestAppliedReadSequence = readState.myLastRead.seq
      latestRequestedReadSequence = max(
        latestRequestedReadSequence,
        readState.myLastRead.seq
      )
      inbox?.apply(readState, for: conversationID)
    } catch {
      guard request == readRequest else {
        return
      }
      latestRequestedReadSequence = latestAppliedReadSequence
      handle(error)
    }
  }
}
