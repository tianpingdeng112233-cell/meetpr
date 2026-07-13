import Foundation
import Network

actor EventFlusher {
  typealias Sleeper = @Sendable (Duration) async throws -> Void

  private let queue: EventQueueStore
  private let baseURL: URL
  private let transport: EventTransport
  private let accessTokenProvider: @Sendable () async -> String?
  private let session: AnalyticsSessionStore
  private let appVersion: String
  private let build: String
  private let encoder: JSONEncoder
  private let sleeper: Sleeper
  private let retryDelays: [Duration]
  private var privacyGateOpen: Bool
  private var collectionEnabled = true
  private var sampledIn = true
  private var configResolved: Bool
  private var lastScreen = AnalyticsScreen.dashboard
  private var eventPayloadTooLargeAttempts: [UUID: Int] = [:]
  private var deferredPayloadTooLargeEventIDs: Set<UUID> = []
  private var feedbackPayloadTooLargeAttempts: [UUID: Int] = [:]
  private var periodicTask: Task<Void, Never>?
  private var reachability: AnalyticsReachability?

  private static let maximumRequestBytes = 1_048_576
  private static let unexpectedPayloadTooLargeRetryLimit = 2

  init(
    queue: EventQueueStore,
    baseURL: URL,
    transport: @escaping EventTransport,
    accessTokenProvider: @escaping @Sendable () async -> String?,
    session: AnalyticsSessionStore,
    appVersion: String,
    build: String,
    privacyGateOpen: Bool,
    configResolved: Bool = false,
    retryDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(4), .seconds(8)],
    sleeper: @escaping Sleeper = { try await Task.sleep(for: $0) }
  ) {
    self.queue = queue
    self.baseURL = baseURL
    self.transport = transport
    self.accessTokenProvider = accessTokenProvider
    self.session = session
    self.appVersion = appVersion
    self.build = build
    self.privacyGateOpen = privacyGateOpen
    self.configResolved = configResolved
    self.retryDelays = retryDelays
    self.sleeper = sleeper
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder
  }

  deinit {
    periodicTask?.cancel()
    reachability?.cancel()
  }

  func start() {
    guard periodicTask == nil else { return }
    let reachability = AnalyticsReachability { [weak self] in
      Task { await self?.flush() }
    }
    self.reachability = reachability
    reachability.start()
    periodicTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(30))
        await self?.flush()
      }
    }
  }

  func setPrivacyGate(open: Bool) {
    privacyGateOpen = open
    if open {
      Task { await flush() }
    }
  }

  func fetchConfig() async -> Bool {
    defer { configResolved = true }
    let request = request(path: "events/config", method: "GET")
    do {
      let (data, response) = try await transport(request, Data())
      guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
        return collectionEnabled
      }
      let config = try JSONDecoder().decode(AnalyticsConfig.self, from: data)
      collectionEnabled = config.enabled
      let metadata = await session.current()
      sampledIn = Self.isSampled(anonID: metadata.anonID, rate: config.sampleRate)
      if !collectionEnabled || !sampledIn {
        await queue.removeAll()
      }
    } catch {
      // Config is fail-open: observability cannot disable the product.
    }
    return collectionEnabled && sampledIn
  }

  func updateScreen(_ screen: AnalyticsScreen) {
    lastScreen = screen
  }

  func flush() async {
    guard privacyGateOpen, configResolved, collectionEnabled, sampledIn else { return }
    await flushEvents()
    await flushFeedback()
  }

  private func flushEvents() async {
    let events = await queue.events(limit: 50, excluding: deferredPayloadTooLargeEventIDs)
    guard !events.isEmpty else { return }
    await send(events: events)
  }

  private func send(events: [AnalyticsEnvelope]) async {
    guard !events.isEmpty else { return }
    let metadata = await session.current()
    let batch = EventBatch(
      anonID: metadata.anonID,
      appVersion: appVersion,
      build: build,
      events: events
    )
    guard let body = try? encoder.encode(batch) else { return }
    if events.count == 1, body.count > Self.maximumRequestBytes {
      await isolateOversizeEvent(events[0])
      return
    }
    let status = await send(path: "events", body: body)
    debugLog("flush batch=\(events.count) status=\(status ?? -1)")
    switch status {
    case 204:
      for event in events {
        eventPayloadTooLargeAttempts[event.id] = nil
        deferredPayloadTooLargeEventIDs.remove(event.id)
      }
      await queue.removeEvents(ids: Set(events.map(\.id)))
    case 413 where events.count > 1:
      let midpoint = events.count / 2
      await send(events: Array(events[..<midpoint]))
      await send(events: Array(events[midpoint...]))
    case 413:
      // A small single event can receive a transient 413 from an intermediary.
      // Keep it on disk and rotate only after a bounded number of attempts so
      // later events can progress without treating 413 as a success ack.
      let event = events[0]
      let attempts = eventPayloadTooLargeAttempts[event.id, default: 0] + 1
      eventPayloadTooLargeAttempts[event.id] = attempts
      if attempts >= Self.unexpectedPayloadTooLargeRetryLimit {
        deferredPayloadTooLargeEventIDs.insert(event.id)
        await queue.moveEventsToBack(ids: [event.id])
      }
    default:
      break
    }
  }

  private func flushFeedback() async {
    for payload in await queue.feedback() {
      let cappedText = String(payload.text.prefix(500))
      if cappedText != payload.text {
        await queue.replaceFeedback(payload.withText(cappedText))
        continue
      }
      guard let body = try? encoder.encode(payload) else { continue }
      let status = await send(path: "events/feedback", body: body)
      debugLog("feedback status=\(status ?? -1)")
      if status == 204 {
        feedbackPayloadTooLargeAttempts[payload.id] = nil
        await queue.removeFeedback(id: payload.id)
      } else if status == 413 {
        let attempts = feedbackPayloadTooLargeAttempts[payload.id, default: 0] + 1
        feedbackPayloadTooLargeAttempts[payload.id] = attempts
        guard attempts >= Self.unexpectedPayloadTooLargeRetryLimit else { break }
        feedbackPayloadTooLargeAttempts[payload.id] = nil
        await isolateOversizeFeedback(payload)
      } else {
        break
      }
    }
  }

  private func isolateOversizeEvent(_ event: AnalyticsEnvelope) async {
    await queue.removeEvents(ids: [event.id])
    await enqueuePayloadError(code: 413)
  }

  private func isolateOversizeFeedback(_ payload: FrictionFeedbackPayload) async {
    await queue.removeFeedback(id: payload.id)
    await enqueuePayloadError(code: 413)
  }

  private func enqueuePayloadError(code: Int) async {
    let metadata = await session.next()
    await queue.enqueue(
      AnalyticsEnvelope(
        eventID: UUID(),
        sessionID: metadata.sessionID,
        seq: metadata.seq,
        name: .clientError,
        props: [
          "domain": .enumCase(ClientErrorDomain.network),
          "code": .int(code),
          "screen": .enumCase(lastScreen),
        ],
        schemaVersion: 1,
        timestamp: Date()
      ))
  }

  private func send(path: String, body: Data) async -> Int? {
    var attempt = 0
    while true {
      var request = request(path: path, method: "POST")
      authorize(&request, token: await accessTokenProvider())
      do {
        let (_, response) = try await transport(request, body)
        guard let response = response as? HTTPURLResponse else { return nil }
        let status = response.statusCode
        let isTransientFailure = status == 429 || (500...599).contains(status)
        guard isTransientFailure, attempt < retryDelays.count else {
          return status
        }
      } catch {
        guard attempt < retryDelays.count else { return nil }
      }
      let delay = retryDelays[attempt]
      attempt += 1
      try? await sleeper(delay)
    }
  }

  private func request(path: String, method: String) -> URLRequest {
    var url = baseURL
    for component in path.split(separator: "/") {
      url.append(path: String(component))
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "accept")
    if method == "POST" {
      request.setValue("application/json", forHTTPHeaderField: "content-type")
    }
    return request
  }

  private func authorize(_ request: inout URLRequest, token: String?) {
    if let token, !token.isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
    }
  }

  nonisolated private static func isSampled(anonID: UUID, rate: Double) -> Bool {
    guard rate > 0 else { return false }
    guard rate < 1 else { return true }
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in anonID.uuidString.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return Double(hash % 10_000) / 10_000 < rate
  }

  nonisolated private func debugLog(_ message: String) {
    #if DEBUG
      print("[Analytics] \(message)")
    #endif
  }
}

private final class AnalyticsReachability: @unchecked Sendable {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.meetpr.analytics.reachability")
  private let onReachable: @Sendable () -> Void

  init(onReachable: @escaping @Sendable () -> Void) {
    self.onReachable = onReachable
  }

  func start() {
    monitor.pathUpdateHandler = { [onReachable] path in
      if path.status == .satisfied { onReachable() }
    }
    monitor.start(queue: queue)
  }

  func cancel() {
    monitor.cancel()
  }
}
