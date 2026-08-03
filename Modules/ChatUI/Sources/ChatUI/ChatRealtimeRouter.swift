import Foundation
import Networking

struct ChatRealtimeSubscription: Sendable {
  let events: AsyncStream<RealtimeEvent>
  let state: AsyncStream<RealtimeConnectionState>
}

/// Broadcasts the session's single realtime stream to independent chat consumers.
///
/// `AsyncStream` consumers must not compete for the same iterator: the inbox
/// and an open conversation each receive their own downstream stream here.
@MainActor
final class ChatRealtimeRouter {
  private var eventContinuations: [UUID: AsyncStream<RealtimeEvent>.Continuation] = [:]
  private var stateContinuations: [UUID: AsyncStream<RealtimeConnectionState>.Continuation] = [:]
  private var currentState = RealtimeConnectionState.disconnected
  private var eventTask: Task<Void, Never>?
  private var stateTask: Task<Void, Never>?

  init(
    events: AsyncStream<RealtimeEvent>,
    state: AsyncStream<RealtimeConnectionState>
  ) {
    eventTask = Task { @MainActor [weak self] in
      for await event in events {
        guard let self else { return }
        for continuation in eventContinuations.values {
          continuation.yield(event)
        }
      }
    }
    stateTask = Task { @MainActor [weak self] in
      for await state in state {
        guard let self else { return }
        currentState = state
        for continuation in stateContinuations.values {
          continuation.yield(state)
        }
      }
    }
  }

  /// Test probe: live downstream continuations across both streams.
  var subscriberCount: Int {
    eventContinuations.count + stateContinuations.count
  }

  func subscribe() -> ChatRealtimeSubscription {
    let eventID = UUID()
    let events = AsyncStream<RealtimeEvent> { continuation in
      eventContinuations[eventID] = continuation
      continuation.onTermination = { @Sendable [weak self] _ in
        Task { @MainActor in
          self?.eventContinuations.removeValue(forKey: eventID)
        }
      }
    }

    let stateID = UUID()
    let state = AsyncStream<RealtimeConnectionState> { continuation in
      stateContinuations[stateID] = continuation
      continuation.yield(currentState)
      continuation.onTermination = { @Sendable [weak self] _ in
        Task { @MainActor in
          self?.stateContinuations.removeValue(forKey: stateID)
        }
      }
    }
    return ChatRealtimeSubscription(events: events, state: state)
  }

  deinit {
    // An inbox released without clear() drops its router here; cancelling the
    // upstream consumers keeps them from idling on the source streams forever.
    eventTask?.cancel()
    stateTask?.cancel()
  }

  func stop() {
    eventTask?.cancel()
    stateTask?.cancel()
    eventTask = nil
    stateTask = nil
    for continuation in eventContinuations.values {
      continuation.finish()
    }
    for continuation in stateContinuations.values {
      continuation.finish()
    }
    eventContinuations.removeAll()
    stateContinuations.removeAll()
  }
}
