import Foundation
import Testing

@testable import StudentKit

@Test func aggregateCompletionCannotBeOverwrittenBySuspendedOlderFailure() async {
  let queue = UploadNotificationDeliveryQueue()
  let delivery = NotificationDeliveryProbe()
  let oldFailure = Task { await queue.perform { await delivery.deliverOldFailure() } }
  await delivery.waitForOldFailure()
  let completion = Task { await queue.perform { await delivery.deliverCompletion() } }
  for _ in 0..<20 { await Task.yield() }
  await delivery.release()
  await oldFailure.value
  await completion.value
  #expect(await delivery.messages == ["failure", "completion"])
}

private actor NotificationDeliveryProbe {
  var messages: [String] = []
  private var entered = false
  private var observers: [CheckedContinuation<Void, Never>] = []
  private var continuation: CheckedContinuation<Void, Never>?
  func deliverOldFailure() async {
    entered = true
    for observer in observers { observer.resume() }
    observers = []
    await withCheckedContinuation { continuation = $0 }
    messages.append("failure")
  }
  func waitForOldFailure() async {
    if entered { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    continuation?.resume()
    continuation = nil
  }
  func deliverCompletion() { messages.append("completion") }
}
