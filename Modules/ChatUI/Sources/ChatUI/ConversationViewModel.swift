import CoreModels
import Foundation
import Networking
import Observation
import RepositoryContracts

public enum ChatDeliveryStatus: Equatable, Sendable {
  case delivered
  case read
}

@Observable
@MainActor
public final class ConversationViewModel {
  public static let maximumTextLength = SetRefMessageLengthPolicy.maximumBodyUTF16Count

  public let conversationID: UUID
  public let currentUserID: UUID
  public internal(set) var messages: [ChatMessage] = []
  public internal(set) var otherLastRead: ChatCursor?
  public internal(set) var hasMoreHistory = false
  public internal(set) var isLoading = false
  public internal(set) var didFinishInitialLoad = false
  public internal(set) var isLoadingOlder = false
  public internal(set) var isPolling = false
  public internal(set) var error: (any Error)?
  public private(set) var setRefSendErrorMessage: String?

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

  public var stagedSetRef: SetRefSendIntent? {
    sendCoordinator.stagedSetRef(in: conversationID)
  }

  public func stagedSetRefLength(note: String) -> SetRefComposerLength? {
    guard let stagedSetRef else { return nil }
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let body = SetRefCanonicalFormatter.body(
      for: stagedSetRef.setRef,
      note: trimmed.isEmpty ? nil : trimmed
    )
    return SetRefComposerLength(
      bodyUTF16Count: body.utf16.count,
      maximumUTF16Count: Self.maximumTextLength
    )
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
  @ObservationIgnored var isRealtimeConnected = false
  @ObservationIgnored var realtimeEventTask: Task<Void, Never>?
  @ObservationIgnored var realtimeStateTask: Task<Void, Never>?
  @ObservationIgnored var realtimeRefreshTask: Task<Void, Never>?
  @ObservationIgnored var realtimeRefreshPending = false
  @ObservationIgnored var pollingWorker: Task<Void, Never>?
  @ObservationIgnored var pollingGeneration: UInt64 = 0
  @ObservationIgnored var pollingOwnerID: UUID?
  @ObservationIgnored var pollingLifetimeContinuation: CheckedContinuation<Void, Never>?

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
    if let subscription = inbox?.realtimeSubscription() {
      attachRealtime(events: subscription.events, state: subscription.state)
    }
  }

  deinit {
    // Cancelling here (not only on re-attach) ends the subscription iterations,
    // whose termination hooks release this conversation's router continuations.
    // Without it every opened-and-closed conversation would leak two
    // subscriptions until the whole chat session tears down.
    realtimeEventTask?.cancel()
    realtimeStateTask?.cancel()
    realtimeRefreshTask?.cancel()
    pollingWorker?.cancel()
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

  @discardableResult
  public func sendStagedSetRef(note: String) -> String? {
    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let length = stagedSetRefLength(note: trimmed) else {
      setRefSendErrorMessage = ChatStrings.trainingShareFailed
      return nil
    }
    guard !length.isOverLimit else {
      setRefSendErrorMessage = ChatStrings.messageTooLong
      return nil
    }
    do {
      let clientID = try sendCoordinator.sendStagedSetRef(
        in: conversationID,
        note: trimmed.isEmpty ? nil : trimmed
      )
      setRefSendErrorMessage = nil
      return clientID
    } catch SetRefSendError.messageTooLong {
      setRefSendErrorMessage = ChatStrings.messageTooLong
      return nil
    } catch {
      setRefSendErrorMessage = ChatStrings.trainingShareFailed
      return nil
    }
  }

  public func discardStagedSetRef() {
    sendCoordinator.discardStagedSetRef(in: conversationID)
    setRefSendErrorMessage = nil
  }

  public func clearSetRefSendError() {
    setRefSendErrorMessage = nil
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

public struct SetRefComposerLength: Equatable, Sendable {
  public let bodyUTF16Count: Int
  public let maximumUTF16Count: Int

  public var isOverLimit: Bool {
    bodyUTF16Count > maximumUTF16Count
  }
}
