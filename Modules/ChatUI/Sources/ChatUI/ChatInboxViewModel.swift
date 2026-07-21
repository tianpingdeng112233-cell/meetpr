import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
public final class ChatInboxViewModel {
  public let currentUserID: UUID
  public private(set) var conversations: [ChatConversation] = []
  public private(set) var totalUnread = 0
  public private(set) var error: (any Error)?

  @ObservationIgnored private let repository: any ChatRepository
  @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
  @ObservationIgnored private let onBindingInvalidated: @Sendable () async -> Void
  @ObservationIgnored private var pollingTask: Task<Void, Never>?
  @ObservationIgnored private var pollingGeneration: UInt64 = 0
  @ObservationIgnored private var refreshRequest: UInt64 = 0
  @ObservationIgnored private var bindingInvalidationReported = false

  public init(
    repository: any ChatRepository,
    currentUserID: UUID,
    sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
      try await Task.sleep(for: duration)
    },
    onBindingInvalidated: @escaping @Sendable () async -> Void = {}
  ) {
    self.repository = repository
    self.currentUserID = currentUserID
    self.sleep = sleep
    self.onBindingInvalidated = onBindingInvalidated
  }

  public func refresh() async {
    refreshRequest &+= 1
    let request = refreshRequest
    do {
      let fetched = try await repository.fetchConversations()
      guard request == refreshRequest else {
        return
      }
      conversations = fetched.sorted(by: Self.conversationOrder)
      totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
      error = nil
      bindingInvalidationReported = false
    } catch {
      guard request == refreshRequest, !error.isChatTaskCancellation else {
        return
      }
      self.error = error
      if error as? ChatRepositoryError == .bindRequired {
        reportBindingInvalidationIfNeeded()
      }
    }
  }

  public func apply(_ readState: ChatReadState, for conversationID: UUID) {
    // Invalidate refreshes already in flight. Their generation only protects
    // against an older *refresh* landing after a newer one; a refresh that
    // sampled the unread count before this mark-read would otherwise return
    // afterwards and write the stale count back, resurrecting a badge the user
    // just cleared.
    refreshRequest &+= 1

    guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
      return
    }
    let conversation = conversations[index]
    guard (conversation.myLastRead?.seq ?? 0) <= readState.myLastRead.seq else {
      return
    }
    conversations[index] = ChatConversation(
      id: conversation.id,
      otherPartyID: conversation.otherPartyID,
      otherPartyName: conversation.otherPartyName,
      lastMessagePreview: conversation.lastMessagePreview,
      lastMessageAt: conversation.lastMessageAt,
      unreadCount: readState.unreadCount,
      myLastRead: readState.myLastRead,
      otherLastRead: conversation.otherLastRead
    )
    totalUnread = conversations.reduce(0) { $0 + $1.unreadCount }
  }

  public func clear() {
    stopPolling()
    refreshRequest &+= 1
    conversations = []
    totalUnread = 0
    error = nil
    bindingInvalidationReported = false
  }

  public func startPolling() {
    guard pollingTask == nil else {
      return
    }
    pollingGeneration &+= 1
    let capturedGeneration = pollingGeneration
    pollingTask = Task { @MainActor [weak self] in
      await self?.poll(generation: capturedGeneration)
    }
  }

  public func stopPolling() {
    pollingGeneration &+= 1
    pollingTask?.cancel()
    pollingTask = nil
  }

  private func poll(generation capturedGeneration: UInt64) async {
    defer {
      if capturedGeneration == pollingGeneration {
        pollingTask = nil
      }
    }
    while !Task.isCancelled, capturedGeneration == pollingGeneration {
      do {
        try await sleep(.seconds(30))
      } catch {
        return
      }
      guard !Task.isCancelled, capturedGeneration == pollingGeneration else {
        return
      }
      await refresh()
    }
  }

  private func reportBindingInvalidationIfNeeded() {
    guard !bindingInvalidationReported else {
      return
    }
    bindingInvalidationReported = true
    let callback = onBindingInvalidated
    Task {
      await callback()
    }
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
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }
}
