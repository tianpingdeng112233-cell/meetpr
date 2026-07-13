import Foundation
import Testing

@testable import Analytics

@Test func disabledCoreProducesNoDiskQueueWrites() async throws {
  let directory = try makeTemporaryDirectory()
  let queue = EventQueueStore(directory: directory)
  let core = AnalyticsCore(queue: queue)
  await core.configure(
    AnalyticsConfiguration(
      baseURL: try #require(URL(string: "https://example.com")),
      transport: { _, _ in throw TestError.transport },
      accessTokenProvider: { nil },
      mode: .disabled,
      privacyNoticeConfirmed: false,
      appVersion: "Demo",
      build: "Demo",
      crashDirectory: directory.appending(path: "crash")))
  await core.track(.appOpen, props: ["cold": .bool(true)])

  #expect(await queue.count() == 0)
  #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "events.json").path))
}

@Test func runtimeDisabledAnalyticsNeverConstructsItsDiskBackedCore() throws {
  let constructions = LockedCounter()
  let analytics = Analytics(makeCore: {
    constructions.increment()
    return AnalyticsCore()
  })
  analytics.prepare(mode: .disabled)
  analytics.configure(
    baseURL: try #require(URL(string: "https://example.com")),
    transport: { _, _ in throw TestError.transport },
    accessTokenProvider: { nil },
    mode: .disabled)
  analytics.track(.appOpen, props: ["cold": .bool(true)])

  #expect(constructions.value == 0)
}

@Test func feedbackTextIsTrimmedAndCappedAtFiveHundredCharacters() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let core = AnalyticsCore(queue: queue)
  await core.submitFrictionText(
    eventID: UUID(),
    flow: .recordSet,
    fromScreen: .todayWorkout,
    trigger: .reEdit,
    text: "  " + String(repeating: "好", count: 600) + "  "
  )

  let payload = try #require(await queue.feedback().first)
  #expect(payload.text.count == 500)
  #expect(!payload.text.hasPrefix(" "))
}

@Test func frictionSignalAndTextUseSeparateEndpointsWithSameEventID() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let recorder = RequestRecorder()
  let core = AnalyticsCore(queue: queue)
  await core.configure(
    AnalyticsConfiguration(
      baseURL: try #require(URL(string: "https://example.com")),
      transport: { request, body in
        await recorder.append(request, body: body)
        if request.url?.path == "/events/config" {
          return (
            try JSONSerialization.data(
              withJSONObject: ["enabled": true, "sample_rate": 1.0]),
            try makeHTTPResponse(status: 200, url: try #require(request.url))
          )
        }
        return (Data(), try makeHTTPResponse(status: 204, url: try #require(request.url)))
      },
      accessTokenProvider: { nil },
      mode: .live,
      privacyNoticeConfirmed: false,
      appVersion: "1.0",
      build: "10",
      crashDirectory: try makeTemporaryDirectory()))
  let context = try #require(
    await core.prepareFrictionFeedback(
      flow: .recordSet,
      fromScreen: .todayWorkout,
      trigger: .reEdit))
  await core.submitFrictionText(
    eventID: context.eventID,
    flow: .recordSet,
    fromScreen: .todayWorkout,
    trigger: .reEdit,
    text: "重量输入不顺手")
  await core.confirmPrivacyNotice()
  await core.track(.appOpen, props: ["cold": .bool(true)])

  let requests = await recorder.snapshot()
  let eventsRequest = try #require(requests.first { $0.0.url?.path == "/events" })
  let feedbackRequest = try #require(
    requests.first { $0.0.url?.path == "/events/feedback" })
  let eventsBody = try #require(
    try JSONSerialization.jsonObject(with: eventsRequest.1) as? [String: Any])
  let events = try #require(eventsBody["events"] as? [[String: Any]])
  let signal = try #require(events.first { $0["name"] as? String == "friction_feedback" })
  let feedback = try #require(
    try JSONSerialization.jsonObject(with: feedbackRequest.1) as? [String: Any])

  #expect(UUID(uuidString: signal["event_id"] as? String ?? "") == context.eventID)
  #expect(UUID(uuidString: feedback["event_id"] as? String ?? "") == context.eventID)
  #expect(feedback["text"] as? String == "重量输入不顺手")
}

private enum TestError: Error {
  case transport
}

private final class LockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int { lock.withLock { count } }

  func increment() {
    lock.withLock { count += 1 }
  }
}
