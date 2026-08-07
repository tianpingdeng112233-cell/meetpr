import Foundation

public struct BackgroundUploadEventToken: Hashable, Sendable {
  public let sessionIdentifier: String
  public let id: UUID

  public init(sessionIdentifier: String, id: UUID = UUID()) {
    self.sessionIdentifier = sessionIdentifier
    self.id = id
  }
}

/// Pure state machine behind the UIApplication background-session completion
/// bridge. Handler registration and URLSession's final delegate callback may
/// arrive in either order; outstanding pipeline work gates completion.
struct BackgroundUploadCompletionState: Sendable {
  private struct Session: Sendable {
    var hasHandler = false
    var eventsDelivered = false
    var outstandingEvents: Set<UUID> = []
  }

  private var sessions: [String: Session] = [:]

  mutating func storeHandler(identifier: String) -> Bool {
    var session = sessions[identifier, default: Session()]
    session.hasHandler = true
    sessions[identifier] = session
    return finishIfPossible(identifier: identifier)
  }

  mutating func beginEvent(identifier: String, id: UUID = UUID()) -> BackgroundUploadEventToken {
    var session = sessions[identifier, default: Session()]
    session.outstandingEvents.insert(id)
    sessions[identifier] = session
    return BackgroundUploadEventToken(sessionIdentifier: identifier, id: id)
  }

  mutating func acknowledgeEvent(_ token: BackgroundUploadEventToken) -> Bool {
    guard var session = sessions[token.sessionIdentifier] else { return false }
    session.outstandingEvents.remove(token.id)
    sessions[token.sessionIdentifier] = session
    let shouldFinish = finishIfPossible(identifier: token.sessionIdentifier)
    discardIdleSession(identifier: token.sessionIdentifier)
    return shouldFinish
  }

  mutating func markEventsDelivered(identifier: String) -> Bool {
    var session = sessions[identifier, default: Session()]
    session.eventsDelivered = true
    sessions[identifier] = session
    return finishIfPossible(identifier: identifier)
  }

  func hasPendingHandler(identifier: String) -> Bool {
    sessions[identifier]?.hasHandler == true
  }

  private mutating func finishIfPossible(identifier: String) -> Bool {
    guard let session = sessions[identifier],
      session.hasHandler,
      session.eventsDelivered,
      session.outstandingEvents.isEmpty
    else { return false }
    sessions[identifier] = nil
    return true
  }

  private mutating func discardIdleSession(identifier: String) {
    guard let session = sessions[identifier],
      !session.hasHandler,
      !session.eventsDelivered,
      session.outstandingEvents.isEmpty
    else { return }
    sessions[identifier] = nil
  }
}

/// Thread-safe runtime wrapper. Delegate callbacks update the state
/// synchronously, preserving URLSession's callback order without unstructured
/// tasks. The stored OS handler is invoked exactly once and outside the lock.
public final class BackgroundUploadCompletionRegistry: @unchecked Sendable {
  private final class CompletionHandler: @unchecked Sendable {
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
      self.action = action
    }

    @MainActor
    func call() {
      action()
    }
  }

  public static let shared = BackgroundUploadCompletionRegistry()

  private let lock = NSLock()
  private var state = BackgroundUploadCompletionState()
  private var handlers: [String: CompletionHandler] = [:]

  public init() {}

  public func store(identifier: String, completion: @escaping @MainActor () -> Void) {
    let handler = lock.withLock { () -> CompletionHandler? in
      handlers[identifier] = CompletionHandler(action: completion)
      guard state.storeHandler(identifier: identifier) else { return nil }
      return handlers.removeValue(forKey: identifier)
    }
    callOnMainActor(handler)
  }

  func beginEvent(identifier: String) -> BackgroundUploadEventToken {
    lock.withLock { state.beginEvent(identifier: identifier) }
  }

  func acknowledgeEvent(_ token: BackgroundUploadEventToken) {
    let handler = lock.withLock { () -> CompletionHandler? in
      guard state.acknowledgeEvent(token) else { return nil }
      return handlers.removeValue(forKey: token.sessionIdentifier)
    }
    callOnMainActor(handler)
  }

  func markEventsDelivered(identifier: String) {
    let handler = lock.withLock { () -> CompletionHandler? in
      guard state.markEventsDelivered(identifier: identifier) else { return nil }
      return handlers.removeValue(forKey: identifier)
    }
    callOnMainActor(handler)
  }

  func hasPendingHandler(identifier: String) -> Bool {
    lock.withLock { state.hasPendingHandler(identifier: identifier) }
  }

  private func callOnMainActor(_ handler: CompletionHandler?) {
    guard let handler else { return }
    Task { @MainActor in
      handler.call()
    }
  }
}

/// Defers rebuilding a background URLSession until UIApplicationDelegate has
/// first retained the matching system completion handler. Registration and
/// wake-up notification are also order-independent.
public final class BackgroundUploadSessionLifecycle: @unchecked Sendable {
  public static let shared = BackgroundUploadSessionLifecycle()

  private let lock = NSLock()
  private var reconnectors: [String: @Sendable () -> Void] = [:]
  private var pendingIdentifiers: Set<String> = []

  public init() {}

  func register(identifier: String, reconnect: @escaping @Sendable () -> Void) {
    let shouldReconnect = lock.withLock {
      reconnectors[identifier] = reconnect
      return pendingIdentifiers.remove(identifier) != nil
    }
    if shouldReconnect { reconnect() }
  }

  public func reconnect(identifier: String) {
    let reconnector = lock.withLock { () -> (@Sendable () -> Void)? in
      guard let reconnector = reconnectors[identifier] else {
        pendingIdentifiers.insert(identifier)
        return nil
      }
      return reconnector
    }
    reconnector?()
  }
}
