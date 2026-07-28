import CoreModels
import Foundation
import Observation
import RepositoryContracts

public enum ChatDeliveryStatus: Equatable, Sendable {
  case delivered
  case read
}

@Observable
@MainActor
public final class ConversationViewModel {
  public static let maximumTextLength = 4_000

  public let conversationID: UUID
  public let currentUserID: UUID
  public internal(set) var messages: [ChatMessage] = []
  public internal(set) var otherLastRead: ChatCursor?
  public internal(set) var hasMoreHistory = false
  public internal(set) var isLoading = false
  public internal(set) var isLoadingOlder = false
  public internal(set) var isPolling = false
  public internal(set) var error: (any Error)?

  public var pending: [ChatOutboxItem] {
    sendCoordinator.outbox(in: conversationID).filter { item in
      switch item.state {
      case .sending, .failed:
        return true
      case .confirmed:
        return false
      }
    }
  }

  public var renderedMessages: [ChatMessage] {
    var bySequence = Dictionary(uniqueKeysWithValues: messages.map { ($0.seq, $0) })
    for item in sendCoordinator.outbox(in: conversationID) {
      if case .confirmed(let message) = item.state {
        bySequence[message.seq] = message
      }
    }
    return bySequence.values.sorted { $0.seq < $1.seq }
  }

  public var hasSendingMessages: Bool {
    pending.contains { item in
      if case .sending = item.state {
        return true
      }
      return false
    }
  }

  @ObservationIgnored let repository: any ChatRepository
  @ObservationIgnored let sendCoordinator: ChatSendCoordinator
  @ObservationIgnored let inbox: ChatInboxViewModel?
  @ObservationIgnored let sleep: @Sendable (Duration) async throws -> Void
  @ObservationIgnored let now: @Sendable () -> Date
  @ObservationIgnored let pageLimit: Int
  @ObservationIgnored var imageURLObtainedAt: [UUID: Date] = [:]
  @ObservationIgnored var imageRenewalsInFlight: Set<UUID> = []
  @ObservationIgnored var lastImageRenewalAttemptAt: [UUID: Date] = [:]
  @ObservationIgnored var loadFailureRenewalAttempted: Set<UUID> = []
  @ObservationIgnored var videoURLObtainedAt: [UUID: Date] = [:]
  @ObservationIgnored var videoRenewalsInFlight: Set<UUID> = []
  /// Prevents an already-removed message from being resurrected by a stale
  /// fetch that was in flight when renewal proved the message inaccessible.
  /// A view model owns one immutable conversation, so a conversation switch
  /// creates a fresh set.
  @ObservationIgnored var removedMessageIDs: Set<UUID> = []
  @ObservationIgnored var readRequest: UInt64 = 0
  @ObservationIgnored var latestRequestedReadSequence = 0
  @ObservationIgnored var latestAppliedReadSequence = 0
  @ObservationIgnored var bindingInvalidationReported = false

  public init(
    conversationID: UUID,
    currentUserID: UUID,
    repository: any ChatRepository,
    sendCoordinator: ChatSendCoordinator,
    inbox: ChatInboxViewModel? = nil,
    sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
      try await Task.sleep(for: duration)
    },
    now: @escaping @Sendable () -> Date = { Date() },
    pageLimit: Int = 50
  ) {
    self.conversationID = conversationID
    self.currentUserID = currentUserID
    self.repository = repository
    self.sendCoordinator = sendCoordinator
    self.inbox = inbox
    self.sleep = sleep
    self.now = now
    self.pageLimit = pageLimit
    synchronizeOutbox()
    observeOutbox()
  }

  @discardableResult
  public func sendText(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= Self.maximumTextLength else {
      return nil
    }
    return sendCoordinator.sendText(in: conversationID, text: trimmed)
  }

  @discardableResult
  public func sendImage(_ imageData: Data) -> String? {
    guard !imageData.isEmpty else {
      return nil
    }
    return sendCoordinator.sendImage(in: conversationID, imageData: imageData)
  }

  public func retry(clientID: String) {
    sendCoordinator.retry(in: conversationID, clientID: clientID)
  }

  public func deliveryStatus(for message: ChatMessage) -> ChatDeliveryStatus? {
    guard
      message.senderID == currentUserID,
      messages.last(where: { $0.senderID == currentUserID })?.id == message.id
    else {
      return nil
    }
    if let otherLastRead, otherLastRead.seq >= message.seq {
      return .read
    }
    return .delivered
  }

  public func message(withID messageID: UUID) -> ChatMessage? {
    messages.first { $0.id == messageID }
  }

}
