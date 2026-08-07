import Foundation

private typealias VoidThrowingContinuation = CheckedContinuation<Void, any Error>

public enum RealtimeConnectionState: Equatable, Sendable {
  case connected
  case disconnected
}

public actor RealtimeClient {
  public nonisolated let events: AsyncStream<RealtimeEvent>
  public nonisolated let state: AsyncStream<RealtimeConnectionState>

  private let baseURL: URL
  private let session: any SessionStateReader
  private let connector: RealtimeConnector
  private let sleep: @Sendable (Duration) async throws -> Void
  private let jitter: @Sendable (Int) -> Duration
  private let eventContinuation: AsyncStream<RealtimeEvent>.Continuation
  private let stateContinuation: AsyncStream<RealtimeConnectionState>.Continuation

  private var runTask: Task<Void, Never>?
  private var activeConnection: (any RealtimeConnection)?
  private var connectionGeneration: UInt64 = 0
  private var wantsConnection = false
  private var connectionState = RealtimeConnectionState.disconnected

  public init(baseURL: URL, session: any SessionStateReader) {
    self.init(
      baseURL: baseURL,
      session: session,
      connector: { request in
        URLSessionRealtimeConnection(request: request)
      },
      sleep: { duration in
        try await Task.sleep(for: duration)
      },
      jitter: { maximumSeconds in
        let upperBound = UInt64(maximumSeconds) * 1_000_000_000
        return .nanoseconds(Int64.random(in: 0...Int64(upperBound)))
      }
    )
  }

  init(
    baseURL: URL,
    session: any SessionStateReader,
    connector: @escaping RealtimeConnector,
    sleep: @escaping @Sendable (Duration) async throws -> Void,
    jitter: @escaping @Sendable (Int) -> Duration
  ) {
    var eventContinuation: AsyncStream<RealtimeEvent>.Continuation?
    events = AsyncStream { eventContinuation = $0 }
    guard let resolvedEventContinuation = eventContinuation else {
      preconditionFailure("Realtime event stream did not install its continuation.")
    }
    self.eventContinuation = resolvedEventContinuation

    var stateContinuation: AsyncStream<RealtimeConnectionState>.Continuation?
    state = AsyncStream { stateContinuation = $0 }
    guard let resolvedStateContinuation = stateContinuation else {
      preconditionFailure("Realtime state stream did not install its continuation.")
    }
    self.stateContinuation = resolvedStateContinuation

    self.baseURL = baseURL
    self.session = session
    self.connector = connector
    self.sleep = sleep
    self.jitter = jitter
    resolvedStateContinuation.yield(.disconnected)
  }

  public func connect() {
    guard !wantsConnection else {
      return
    }
    wantsConnection = true
    connectionGeneration &+= 1
    let generation = connectionGeneration
    runTask = Task { [weak self] in
      await self?.run(generation: generation)
    }
  }

  public func disconnect() async {
    wantsConnection = false
    connectionGeneration &+= 1
    let generation = connectionGeneration
    runTask?.cancel()
    runTask = nil
    let connection = activeConnection
    activeConnection = nil
    // Publish before the first suspension point: a connect() racing with the
    // await below bumps the generation, and a post-await publish would then be
    // suppressed — leaving a stale .connected that keeps polling suspended.
    transition(to: .disconnected, generation: generation)
    await connection?.cancel()
  }

  /// Test probe: whether the client currently wants a live connection.
  public func isConnectionDesired() -> Bool {
    wantsConnection
  }

  /// Test probe: the active run task, captured before disconnect() clears it
  /// so tests can await its exit as a completion barrier.
  func activeRunTask() -> Task<Void, Never>? {
    runTask
  }

  private func run(generation: UInt64) async {
    var maximumBackoffSeconds = 1

    while shouldContinue(generation: generation) {
      if await runAttempt(generation: generation) {
        maximumBackoffSeconds = 1
      }
      transition(to: .disconnected, generation: generation)
      guard shouldContinue(generation: generation) else { return }

      do {
        try await sleep(jitter(maximumBackoffSeconds))
      } catch {
        return
      }
      maximumBackoffSeconds = min(maximumBackoffSeconds * 2, 30)
    }

    if generation == connectionGeneration {
      runTask = nil
      activeConnection = nil
    }
  }

  private func runAttempt(generation: UInt64) async -> Bool {
    do {
      let request = try await makeRequest()
      guard shouldContinue(generation: generation) else { return false }
      let connection = try await connector(request)
      guard shouldContinue(generation: generation) else {
        await connection.cancel()
        return false
      }
      activeConnection = connection

      var receivedHello = false
      let pingTask = makePingTask(for: connection)
      do {
        while shouldContinue(generation: generation) {
          let frame = try await connection.receive()
          guard shouldContinue(generation: generation) else { break }
          guard let event = RealtimeEvent.decode(frame.encodedData) else { continue }
          if event == .hello {
            receivedHello = true
            transition(to: .connected, generation: generation)
          }
          eventContinuation.yield(event)
        }
      } catch {
        // Any receive or ping failure returns to the disconnected fallback.
      }
      pingTask.cancel()
      await connection.cancel()
      if shouldContinue(generation: generation) {
        activeConnection = nil
      }
      return receivedHello
    } catch {
      // Token refresh, handshake, and transport errors share one retry path.
      return false
    }
  }

  private func makePingTask(for connection: any RealtimeConnection) -> Task<Void, Never> {
    let sleep = sleep
    return Task {
      while !Task.isCancelled {
        do {
          try await sleep(.seconds(20))
          try Task.checkCancellation()
          try await connection.sendPing()
        } catch is CancellationError {
          return
        } catch {
          await connection.cancel()
          return
        }
      }
    }
  }

  private func makeRequest() async throws -> URLRequest {
    let token = try await session.accessToken()
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    switch components?.scheme?.lowercased() {
    case "http": components?.scheme = "ws"
    case "https": components?.scheme = "wss"
    default: break
    }
    guard var realtimeURL = components?.url else {
      throw RealtimeClientError.invalidBaseURL
    }
    realtimeURL.append(path: "realtime")
    var request = URLRequest(url: realtimeURL)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }

  private func shouldContinue(generation: UInt64) -> Bool {
    wantsConnection && generation == connectionGeneration && !Task.isCancelled
  }

  /// Only the current generation may publish state: a stale run task unwinding
  /// after `disconnect()`/`connect()` interleaving must not overwrite the state
  /// the newer connection already published.
  private func transition(to newState: RealtimeConnectionState, generation: UInt64) {
    guard generation == connectionGeneration else { return }
    guard connectionState != newState else { return }
    connectionState = newState
    stateContinuation.yield(newState)
  }
}

enum RealtimeClientError: Error, Equatable, Sendable {
  case invalidBaseURL
}

enum RealtimeFrame: Sendable {
  case text(String)
  case data(Data)

  var encodedData: Data {
    switch self {
    case .text(let text): Data(text.utf8)
    case .data(let data): data
    }
  }
}

protocol RealtimeConnection: Sendable {
  func receive() async throws -> RealtimeFrame
  func sendPing() async throws
  func cancel() async
}

typealias RealtimeConnector = @Sendable (URLRequest) async throws -> any RealtimeConnection

private final class URLSessionRealtimeConnection: RealtimeConnection, @unchecked Sendable {
  private let urlSession: URLSession
  private let task: URLSessionWebSocketTask

  init(request: URLRequest) {
    let configuration = URLSessionConfiguration.default
    urlSession = URLSession(configuration: configuration)
    task = urlSession.webSocketTask(with: request)
    task.resume()
  }

  func receive() async throws -> RealtimeFrame {
    switch try await task.receive() {
    case .string(let text): .text(text)
    case .data(let data): .data(data)
    @unknown default: throw RealtimeTransportError.unsupportedFrame
    }
  }

  func sendPing() async throws {
    try await withCheckedThrowingContinuation { (continuation: VoidThrowingContinuation) in
      task.sendPing { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  func cancel() async {
    task.cancel(with: .goingAway, reason: nil)
    urlSession.invalidateAndCancel()
  }
}

private enum RealtimeTransportError: Error {
  case unsupportedFrame
}
