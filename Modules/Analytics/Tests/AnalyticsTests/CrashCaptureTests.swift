import Foundation
import Testing

@testable import Analytics

@Test func pendingCrashBecomesOneClientErrorOnNextConfigure() async throws {
  let queue = EventQueueStore(directory: try makeTemporaryDirectory())
  let pendingSessionID = UUID()
  let pending = PendingCrash(
    signalNumber: 11,
    context: CrashContext(
      anonID: UUID(), sessionID: pendingSessionID, screen: .todayWorkout))
  let capturedContexts = LockedCrashContexts()
  let core = AnalyticsCore(
    queue: queue,
    installCrashCapture: { _, context in
      capturedContexts.append(context)
      return pending
    },
    updateCrashCapture: { capturedContexts.append($0) })
  await core.configure(
    AnalyticsConfiguration(
      baseURL: try #require(URL(string: "https://example.com")),
      transport: { request, _ in
        (Data(), try makeHTTPResponse(status: 204, url: try #require(request.url)))
      },
      accessTokenProvider: { nil },
      mode: .live,
      privacyNoticeConfirmed: false,
      appVersion: "1.0",
      build: "10",
      crashDirectory: try makeTemporaryDirectory()))

  let events = await queue.events()
  #expect(events.count == 1)
  #expect(events.first?.name == .clientError)
  #expect(events.first?.props["domain"] == .enumCase("unknown"))
  #expect(events.first?.props["code"] == .int(11))
  #expect(events.first?.props["screen"] == .enumCase("today_workout"))
  #expect(events.first?.sessionID == pendingSessionID)
  #expect(capturedContexts.values.first?.screen == .dashboard)

  await core.track(.screenView, props: ["screen": .enumCase(AnalyticsScreen.coachReceiving)])
  #expect(capturedContexts.values.last?.screen == .coachReceiving)
}

private final class LockedCrashContexts: @unchecked Sendable {
  private let lock = NSLock()
  private var contexts: [CrashContext] = []

  var values: [CrashContext] { lock.withLock { contexts } }

  func append(_ context: CrashContext) {
    lock.withLock { contexts.append(context) }
  }
}
