import Foundation
import Testing

@testable import Analytics

@Test func flusherDeletesOnlyAfterExact204() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let status = LockedStatus(500)
  let flusher = makeFlusher(queue: queue) { request, _ in
    (Data(), try makeHTTPResponse(status: status.value, url: try #require(request.url)))
  }

  await flusher.flush()
  #expect(await queue.count() == 1)
  status.value = 204
  await flusher.flush()
  #expect(await queue.count() == 0)
}

@Test func flusherSplits413BatchAndDoesNotWedge() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  for index in 0..<4 { await queue.enqueue(makeEvent(seq: index)) }
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue) { request, body in
    await recorder.append(request, body: body)
    let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    let count = (object?["events"] as? [Any])?.count ?? 0
    return (
      Data(),
      try makeHTTPResponse(status: count > 1 ? 413 : 204, url: try #require(request.url))
    )
  }

  await flusher.flush()
  #expect(await queue.count() == 0)
  #expect(await recorder.count() == 7)
}

@Test func privacyGateKeepsEventsOnDeviceUntilConfirmed() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue, privacyGateOpen: false) { request, body in
    await recorder.append(request, body: body)
    return (Data(), try makeHTTPResponse(status: 204, url: try #require(request.url)))
  }

  await flusher.flush()
  #expect(await recorder.count() == 0)
  #expect(await queue.count() == 1)
  await flusher.setPrivacyGate(open: true)
  await flusher.flush()
  #expect(await queue.count() == 0)
}

@Test func unresolvedKillSwitchConfigPreventsFlushEvenWhenPrivacyGateIsOpen() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue, configResolved: false) { request, body in
    await recorder.append(request, body: body)
    return (Data(), try makeHTTPResponse(status: 204, url: try #require(request.url)))
  }

  await flusher.flush()

  #expect(await recorder.count() == 0)
  #expect(await queue.count() == 1)
}

@Test func unexpectedSingleEvent413IsRetainedAfterBoundedAttempts() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let event = makeEvent()
  await queue.enqueue(event)
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue) { request, body in
    await recorder.append(request, body: body)
    return (Data(), try makeHTTPResponse(status: 413, url: try #require(request.url)))
  }

  await flusher.flush()
  await flusher.flush()
  await flusher.flush()

  #expect(await recorder.count() == 2)
  #expect(await queue.events().map(\.id) == [event.id])
}

@Test func locallyOversizeSingleEventIsReplacedByClientError() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let event = AnalyticsEnvelope(
    eventID: UUID(),
    sessionID: UUID(),
    seq: 0,
    name: .appOpen,
    props: ["cold": .enumCase(String(repeating: "x", count: 1_100_000))],
    schemaVersion: 1,
    timestamp: Date())
  await queue.enqueue(event)
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue) { request, body in
    await recorder.append(request, body: body)
    return (Data(), try makeHTTPResponse(status: 413, url: try #require(request.url)))
  }

  await flusher.flush()

  #expect(await recorder.count() == 0)
  #expect(await queue.events().map(\.name) == [.clientError])
  #expect(await queue.events().first?.props["code"] == .int(413))
}

@Test func feedbackIsCappedThenRequiresRepeated413BeforeIsolation() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let payload = FrictionFeedbackPayload(
    eventID: UUID(),
    anonID: UUID(),
    sessionID: UUID(),
    flow: .recordSet,
    fromScreen: .todayWorkout,
    trigger: .reEdit,
    text: String(repeating: "好", count: 600),
    timestamp: Date())
  await queue.enqueue(payload)
  let recorder = RequestRecorder()
  let flusher = makeFlusher(queue: queue) { request, body in
    await recorder.append(request, body: body)
    return (Data(), try makeHTTPResponse(status: 413, url: try #require(request.url)))
  }

  await flusher.flush()
  #expect(await queue.feedback().first?.text.count == 500)
  #expect(await recorder.count() == 0)
  await flusher.flush()
  #expect(await queue.feedback().count == 1)
  await flusher.flush()

  #expect(await recorder.count() == 2)
  #expect(await queue.feedback().isEmpty)
  #expect(await queue.events().map(\.name) == [.clientError])
}

@Test func killSwitchDisabledDrainsQueue() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let config = try JSONSerialization.data(
    withJSONObject: ["enabled": false, "sample_rate": 1.0])
  let flusher = makeFlusher(queue: queue) { request, _ in
    (config, try makeHTTPResponse(status: 200, url: try #require(request.url)))
  }

  #expect(await flusher.fetchConfig() == false)
  #expect(await queue.count() == 0)
}

@Test func rateLimitRetriesToCapWithBackoffAndRetainsBatch() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let recorder = RequestRecorder()
  let sleeper = SleepRecorder()
  let flusher = makeFlusher(
    queue: queue,
    retryDelays: [.seconds(1), .seconds(2)],
    sleeper: { duration in await sleeper.append(duration) },
    transport: { request, body in
      await recorder.append(request, body: body)
      return (Data(), try makeHTTPResponse(status: 429, url: try #require(request.url)))
    })

  await flusher.flush()

  #expect(await recorder.count() == 3)
  #expect(await sleeper.count() == 2)
  #expect(await queue.count() == 1)
}

@Test func serverFailureRetriesToCapAndRetainsBatch() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let recorder = RequestRecorder()
  let flusher = makeFlusher(
    queue: queue,
    retryDelays: [.zero, .zero],
    transport: { request, body in
      await recorder.append(request, body: body)
      return (Data(), try makeHTTPResponse(status: 503, url: try #require(request.url)))
    })

  await flusher.flush()

  #expect(await recorder.count() == 3)
  #expect(await queue.count() == 1)
}

@Test func configFailureIsFailOpenAndRetainsQueue() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let flusher = makeFlusher(queue: queue) { _, _ in
    throw AnalyticsTestError.transport
  }

  #expect(await flusher.fetchConfig())
  #expect(await queue.count() == 1)
}

@Test func zeroSampleRateStablyDrainsQueue() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  await queue.enqueue(makeEvent())
  let config = try JSONSerialization.data(
    withJSONObject: ["enabled": true, "sample_rate": 0.0])
  let flusher = makeFlusher(queue: queue) { request, _ in
    (config, try makeHTTPResponse(status: 200, url: try #require(request.url)))
  }

  #expect(await flusher.fetchConfig() == false)
  #expect(await queue.count() == 0)
}

private func makeFlusher(
  queue: EventQueueStore,
  privacyGateOpen: Bool = true,
  configResolved: Bool = true,
  retryDelays: [Duration] = [],
  sleeper: @escaping EventFlusher.Sleeper = { _ in },
  transport: @escaping EventTransport
) -> EventFlusher {
  EventFlusher(
    queue: queue,
    baseURL: URL(string: "https://example.com") ?? URL(fileURLWithPath: "/"),
    transport: transport,
    accessTokenProvider: { nil },
    session: AnalyticsSessionStore(),
    appVersion: "1.0",
    build: "10",
    privacyGateOpen: privacyGateOpen,
    configResolved: configResolved,
    retryDelays: retryDelays,
    sleeper: sleeper
  )
}

private final class LockedStatus: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Int

  init(_ value: Int) { stored = value }

  var value: Int {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}

private actor SleepRecorder {
  private var durations: [Duration] = []

  func append(_ duration: Duration) {
    durations.append(duration)
  }

  func count() -> Int { durations.count }
}

private enum AnalyticsTestError: Error {
  case transport
}
