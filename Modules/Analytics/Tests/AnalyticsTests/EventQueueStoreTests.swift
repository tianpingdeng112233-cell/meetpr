import Foundation
import Testing

@testable import Analytics

@Test func queuePersistsAcrossColdStart() async throws {
  let directory = try makeTemporaryDirectory()
  let event = makeEvent()
  let first = EventQueueStore(directory: directory)
  await first.enqueue(event)

  let relaunched = EventQueueStore(directory: directory)
  let persisted = await relaunched.events()
  #expect(persisted.map(\.id) == [event.id])
  #expect(persisted.map(\.name) == [event.name])
}

@Test func queueCapsAtOneThousandAndDropsOldest() async throws {
  let store = EventQueueStore(directory: try makeTemporaryDirectory())
  let base = Date()
  for index in 0...1_000 {
    await store.enqueue(makeEvent(seq: index, timestamp: base.addingTimeInterval(Double(index))))
  }

  let events = await store.events(limit: 2_000)
  #expect(events.count == 1_000)
  #expect(events.first?.seq == 1)
  #expect(events.last?.seq == 1_000)
}

@Test func queueDropsEventsOlderThanSevenDays() async throws {
  let now = Date()
  let store = EventQueueStore(
    directory: try makeTemporaryDirectory(),
    now: { now }
  )
  await store.enqueue(makeEvent(seq: 0, timestamp: now.addingTimeInterval(-604_801)))
  await store.enqueue(makeEvent(seq: 1, timestamp: now))

  #expect(await store.events().map(\.seq) == [1])
}

@Test func corruptQueueFileReadsAsEmptyWithoutCrashing() async throws {
  let directory = try makeTemporaryDirectory()
  try Data("not-json".utf8).write(to: directory.appending(path: "events.json"))

  let store = EventQueueStore(directory: directory)
  #expect(await store.count() == 0)
}
