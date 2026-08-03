import Foundation
import Testing

@testable import StudentKit

@Test func completionStatePairsDeliveredBeforeStore() {
  var state = BackgroundUploadCompletionState()
  let identifier = "delivered-first"

  let delivered = state.markEventsDelivered(identifier: identifier)
  let stored = state.storeHandler(identifier: identifier)
  #expect(!delivered)
  #expect(stored)
}

@Test func completionStateWaitsForQueuedEventsWhenDeliveredPrecedesStore() {
  var state = BackgroundUploadCompletionState()
  let identifier = "queued-before-store"
  let token = state.beginEvent(identifier: identifier)

  let delivered = state.markEventsDelivered(identifier: identifier)
  let stored = state.storeHandler(identifier: identifier)
  let acknowledged = state.acknowledgeEvent(token)
  #expect(!delivered)
  #expect(!stored)
  #expect(acknowledged)
}

@Test func completionStateMakesDuplicateDeliveryAndAcknowledgementIdempotent() {
  var state = BackgroundUploadCompletionState()
  let identifier = "duplicate-callbacks"
  let token = state.beginEvent(identifier: identifier)

  let stored = state.storeHandler(identifier: identifier)
  let firstDelivery = state.markEventsDelivered(identifier: identifier)
  let secondDelivery = state.markEventsDelivered(identifier: identifier)
  let firstAcknowledgement = state.acknowledgeEvent(token)
  let secondAcknowledgement = state.acknowledgeEvent(token)
  #expect(!stored)
  #expect(!firstDelivery)
  #expect(!secondDelivery)
  #expect(firstAcknowledgement)
  #expect(!secondAcknowledgement)
}

@Test func completionStateHandlesEventAcknowledgedBeforeHandlerAndDelivery() {
  var state = BackgroundUploadCompletionState()
  let identifier = "event-first"
  let token = state.beginEvent(identifier: identifier)

  let acknowledged = state.acknowledgeEvent(token)
  let stored = state.storeHandler(identifier: identifier)
  let delivered = state.markEventsDelivered(identifier: identifier)
  #expect(!acknowledged)
  #expect(!stored)
  #expect(delivered)
}

@Test func completionRegistryInvokesHandlerExactlyOnceOnMainThread() async throws {
  let registry = BackgroundUploadCompletionRegistry()
  let identifier = "runtime-\(UUID().uuidString)"
  let token = registry.beginEvent(identifier: identifier)
  let counter = LockedCounter()

  registry.markEventsDelivered(identifier: identifier)
  registry.store(identifier: identifier) {
    counter.increment(wasMainThread: Thread.isMainThread)
  }
  registry.markEventsDelivered(identifier: identifier)
  registry.acknowledgeEvent(token)
  registry.acknowledgeEvent(token)

  try await waitUntil { counter.value == 1 }
  #expect(counter.value == 1)
  #expect(counter.allCallsWereOnMainThread)
}

@Test func sessionLifecycleReconnectsForEitherRegistrationOrder() {
  let reconnectFirst = BackgroundUploadSessionLifecycle()
  let firstCounter = LockedCounter()
  reconnectFirst.reconnect(identifier: "first")
  reconnectFirst.register(identifier: "first") { firstCounter.increment() }

  let registerFirst = BackgroundUploadSessionLifecycle()
  let secondCounter = LockedCounter()
  registerFirst.register(identifier: "second") { secondCounter.increment() }
  registerFirst.reconnect(identifier: "second")

  #expect(firstCounter.value == 1)
  #expect(secondCounter.value == 1)
}

@Test func uploadFailureNavigationBuffersColdLaunchDestination() async throws {
  let navigation = UploadFailureNavigation.shared
  let destination = UploadFailureDestination(setLogID: UUID(), trainingDate: Date())
  navigation.openFailedAttachment(destination)

  for await received in navigation.events {
    #expect(received == destination)
    return
  }
  Issue.record("Expected a buffered failed-attachment route")
}

@Test func uploadFailureNotificationPayloadRoundTripsHistoricalDestination() throws {
  let destination = UploadFailureDestination(
    setLogID: UUID(),
    trainingDate: Date(timeIntervalSince1970: 1_775_174_400)
  )

  let decoded = try #require(
    UploadFailureDestination(notificationUserInfo: destination.notificationUserInfo)
  )

  #expect(decoded == destination)
}

private final class LockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0
  private var mainThreadStorage = true

  var value: Int { lock.withLock { storage } }
  var allCallsWereOnMainThread: Bool { lock.withLock { mainThreadStorage } }

  func increment() {
    lock.withLock { storage += 1 }
  }

  func increment(wasMainThread: Bool) {
    lock.withLock {
      storage += 1
      mainThreadStorage = mainThreadStorage && wasMainThread
    }
  }
}
