import Foundation
import Testing

@testable import Analytics

@Test func anonIDPersistsAndSequenceIsMonotonic() async throws {
  let suite = "AnalyticsSessionStoreTests.\(UUID().uuidString)"
  defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

  let first = AnalyticsSessionStore(
    defaults: try #require(UserDefaults(suiteName: suite)), keyPrefix: suite)
  let firstEvent = await first.next()
  let secondEvent = await first.next()
  let relaunched = AnalyticsSessionStore(
    defaults: try #require(UserDefaults(suiteName: suite)), keyPrefix: suite)

  #expect(firstEvent.anonID == secondEvent.anonID)
  #expect(firstEvent.seq == 0)
  #expect(secondEvent.seq == 1)
  #expect(await relaunched.current().anonID == firstEvent.anonID)
}

@Test func sessionOnlyResetsAfterThirtyMinutesInBackground() async {
  let clock = TestClock(Date())
  let store = AnalyticsSessionStore(now: { clock.now() })
  let initial = await store.current().sessionID

  await store.didEnterBackground()
  clock.advance(by: 1_799)
  await store.willEnterForeground()
  #expect(await store.current().sessionID == initial)

  await store.didEnterBackground()
  clock.advance(by: 1_800)
  await store.willEnterForeground()
  #expect(await store.current().sessionID != initial)
  #expect(await store.next().seq == 0)
}
