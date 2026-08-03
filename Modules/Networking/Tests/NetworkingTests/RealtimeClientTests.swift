import CoreModels
import Foundation
import Testing

@testable import Networking

@Suite struct RealtimeClientTests {
  @Test func helloConnectsWithBearerHeaderAndTokenNeverEntersURL() async throws {
    let connection = ControllableRealtimeConnection()
    await connection.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    let connector = RecordingRealtimeConnector(connections: [connection])
    let client = makeClient(connector: connector)
    let states = RealtimeStateRecorder()
    let stateTask = Task {
      for await state in client.state {
        await states.record(state)
      }
    }

    await client.connect()

    #expect(await realtimeEventually { await states.values.contains(.connected) })
    let request = try #require(await connector.requests.first)
    #expect(request.url?.scheme == "ws")
    #expect(request.url?.path == "/api/realtime")
    #expect(request.url?.query == nil)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")

    await client.disconnect()
    #expect(await realtimeEventually { await connection.wasCancelled })
    stateTask.cancel()
  }

  @Test func failuresUseCappedExponentialBackoffAndDisconnectStopsReconnects() async {
    let connector = RecordingRealtimeConnector(
      connections: (0..<12).map { _ in ControllableRealtimeConnection(failsImmediately: true) }
    )
    let clock = RetryClock()
    let client = RealtimeClient(
      baseURL: URL(string: "https://example.com") ?? URL(filePath: "/invalid"),
      session: RealtimeSessionStub(),
      connector: { request in try await connector.connect(request) },
      sleep: { duration in try await clock.sleep(for: duration) },
      jitter: { .seconds($0) }
    )

    await client.connect()
    #expect(await realtimeEventually { await clock.retryDelays.count >= 7 })
    #expect(Array(await clock.retryDelays.prefix(7)) == [1, 2, 4, 8, 16, 30, 30])

    await client.disconnect()
    let attemptsAfterDisconnect = await connector.requests.count
    for _ in 0..<50 { await Task.yield() }
    #expect(await connector.requests.count == attemptsAfterDisconnect)
  }

  @Test func helloResetsBackoffBeforeTheNextFailure() async {
    let first = ControllableRealtimeConnection(failsImmediately: true)
    let second = ControllableRealtimeConnection()
    let third = ControllableRealtimeConnection(failsImmediately: true)
    await second.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    let connector = RecordingRealtimeConnector(connections: [first, second, third])
    let clock = ControlledRetryClock()
    let client = RealtimeClient(
      baseURL: URL(string: "http://example.com") ?? URL(filePath: "/invalid"),
      session: RealtimeSessionStub(),
      connector: { request in try await connector.connect(request) },
      sleep: { duration in try await clock.sleep(for: duration) },
      jitter: { .seconds($0) }
    )
    let states = RealtimeStateRecorder()
    let stateTask = Task {
      for await state in client.state {
        await states.record(state)
      }
    }

    await client.connect()
    #expect(await realtimeEventually { await clock.retryDelays == [1] })
    await clock.resumeNextRetry()
    #expect(await realtimeEventually { await connector.requests.count == 2 })
    await second.fail()
    #expect(await realtimeEventually { await clock.retryDelays == [1, 1] })
    #expect(
      await realtimeEventually { await states.values.suffix(2) == [.connected, .disconnected] })

    await client.disconnect()
    stateTask.cancel()
  }

  @Test func sendsProtocolPingEveryTwentySeconds() async {
    let connection = ControllableRealtimeConnection()
    await connection.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    let connector = RecordingRealtimeConnector(connections: [connection])
    let clock = PingClock()
    let client = RealtimeClient(
      baseURL: URL(string: "https://example.com") ?? URL(filePath: "/invalid"),
      session: RealtimeSessionStub(),
      connector: { request in try await connector.connect(request) },
      sleep: { duration in try await clock.sleep(for: duration) },
      jitter: { .seconds($0) }
    )

    await client.connect()
    #expect(await realtimeEventually { await clock.hasPendingPing })
    await clock.resumePing()
    #expect(await realtimeEventually { await connection.pingCount == 1 })

    await client.disconnect()
    await clock.cancelPing()
  }

  @Test func disconnectPublishesDisconnectedBeforeItsSuspensionEvenWhenConnectRaces() async {
    let first = ControllableRealtimeConnection(hangsOnCancel: true)
    let second = ControllableRealtimeConnection()
    await first.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    await second.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    let connector = RecordingRealtimeConnector(connections: [first, second])
    let client = makeClient(connector: connector)
    let states = RealtimeStateRecorder()
    let stateTask = Task {
      for await state in client.state {
        await states.record(state)
      }
    }

    await client.connect()
    #expect(await realtimeEventually { await states.values.last == .connected })

    // disconnect() parks inside the old connection's hanging cancel(); the
    // .disconnected must already be out before that suspension point.
    let disconnectTask = Task { await client.disconnect() }
    #expect(await realtimeEventually { await states.values.last == .disconnected })

    // A connect() racing the still-suspended disconnect() must reach
    // .connected, not get lost behind a stale suppressed publish.
    await client.connect()
    #expect(await realtimeEventually { await states.values.last == .connected })

    await first.releaseCancel()
    await disconnectTask.value
    for _ in 0..<100 { await Task.yield() }
    #expect(await states.values == [.disconnected, .connected, .disconnected, .connected])

    await client.disconnect()
    stateTask.cancel()
  }

  @Test func staleRunCannotOverwriteStateAfterReconnect() async {
    let first = ControllableRealtimeConnection()
    let second = ControllableRealtimeConnection()
    await first.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    await second.enqueue(.text(#"{"type":"hello","payload":{}}"#))
    let connector = RecordingRealtimeConnector(connections: [first, second])
    let client = makeClient(connector: connector)
    let states = RealtimeStateRecorder()
    let stateTask = Task {
      for await state in client.state {
        await states.record(state)
      }
    }

    await client.connect()
    #expect(await realtimeEventually { await states.values.last == .connected })
    await client.disconnect()
    #expect(await realtimeEventually { await states.values.last == .disconnected })
    await client.connect()
    #expect(await realtimeEventually { await states.values.last == .connected })

    // Let the first generation's run task fully unwind: it must not publish a
    // stale .disconnected over the second connection's .connected.
    for _ in 0..<100 { await Task.yield() }
    #expect(await states.values == [.disconnected, .connected, .disconnected, .connected])

    await client.disconnect()
    stateTask.cancel()
  }

  private func makeClient(connector: RecordingRealtimeConnector) -> RealtimeClient {
    RealtimeClient(
      baseURL: URL(string: "http://example.com/api") ?? URL(filePath: "/invalid"),
      session: RealtimeSessionStub(),
      connector: { request in try await connector.connect(request) },
      sleep: { duration in try await Task.sleep(for: duration) },
      jitter: { .seconds($0) }
    )
  }
}

private struct RealtimeSessionStub: SessionStateReader {
  func accessToken() async throws -> String { "secret-token" }

  func currentUser() async throws -> User {
    throw SessionStateReaderError.missingCurrentUser
  }
}

private enum RealtimeTestError: Error {
  case disconnected
  case noConnection
}

private actor ControllableRealtimeConnection: RealtimeConnection {
  private var frames: [RealtimeFrame] = []
  private var waiter: CheckedContinuation<RealtimeFrame, any Error>?
  private let failsImmediately: Bool
  private let hangsOnCancel: Bool
  private var hasFailed = false
  private var cancelWaiter: CheckedContinuation<Void, Never>?
  private(set) var wasCancelled = false
  private(set) var pingCount = 0

  init(failsImmediately: Bool = false, hangsOnCancel: Bool = false) {
    self.failsImmediately = failsImmediately
    self.hangsOnCancel = hangsOnCancel
  }

  func releaseCancel() {
    cancelWaiter?.resume()
    cancelWaiter = nil
  }

  func enqueue(_ frame: RealtimeFrame) {
    if let waiter {
      self.waiter = nil
      waiter.resume(returning: frame)
    } else {
      frames.append(frame)
    }
  }

  func fail() {
    hasFailed = true
    waiter?.resume(throwing: RealtimeTestError.disconnected)
    waiter = nil
  }

  func receive() async throws -> RealtimeFrame {
    if failsImmediately || hasFailed || wasCancelled {
      throw RealtimeTestError.disconnected
    }
    if !frames.isEmpty {
      return frames.removeFirst()
    }
    return try await withCheckedThrowingContinuation { continuation in
      waiter = continuation
    }
  }

  func sendPing() async throws {
    if wasCancelled {
      throw RealtimeTestError.disconnected
    }
    pingCount += 1
  }

  func cancel() async {
    waiter?.resume(throwing: RealtimeTestError.disconnected)
    waiter = nil
    if hangsOnCancel, !wasCancelled {
      wasCancelled = true
      await withCheckedContinuation { cancelWaiter = $0 }
      return
    }
    wasCancelled = true
  }
}

private actor RecordingRealtimeConnector {
  private var connections: [ControllableRealtimeConnection]
  private(set) var requests: [URLRequest] = []

  init(connections: [ControllableRealtimeConnection]) {
    self.connections = connections
  }

  func connect(_ request: URLRequest) throws -> any RealtimeConnection {
    requests.append(request)
    guard !connections.isEmpty else {
      throw RealtimeTestError.noConnection
    }
    return connections.removeFirst()
  }
}

private actor RetryClock {
  private(set) var retryDelays: [Int] = []

  func sleep(for duration: Duration) async throws {
    if duration == .seconds(20) {
      try await Task.sleep(for: .seconds(3_600))
      return
    }
    retryDelays.append(Self.seconds(duration))
  }

  private static func seconds(_ duration: Duration) -> Int {
    Int(duration.components.seconds)
  }
}

private actor ControlledRetryClock {
  private(set) var retryDelays: [Int] = []
  private var continuations: [CheckedContinuation<Void, any Error>] = []

  func sleep(for duration: Duration) async throws {
    if duration == .seconds(20) {
      try await Task.sleep(for: .seconds(3_600))
      return
    }
    retryDelays.append(Int(duration.components.seconds))
    try await withCheckedThrowingContinuation { continuation in
      continuations.append(continuation)
    }
  }

  func resumeNextRetry() {
    guard !continuations.isEmpty else { return }
    continuations.removeFirst().resume()
  }
}

private actor RealtimeStateRecorder {
  private(set) var values: [RealtimeConnectionState] = []

  func record(_ state: RealtimeConnectionState) {
    values.append(state)
  }
}

private actor PingClock {
  private var continuation: CheckedContinuation<Void, any Error>?

  var hasPendingPing: Bool { continuation != nil }

  func sleep(for duration: Duration) async throws {
    guard duration == .seconds(20) else { return }
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
    }
  }

  func resumePing() {
    continuation?.resume()
    continuation = nil
  }

  func cancelPing() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
}

private func realtimeEventually(
  attempts: Int = 1_000,
  _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
  for _ in 0..<attempts {
    if await condition() { return true }
    try? await Task.sleep(for: .milliseconds(1))
  }
  return false
}
