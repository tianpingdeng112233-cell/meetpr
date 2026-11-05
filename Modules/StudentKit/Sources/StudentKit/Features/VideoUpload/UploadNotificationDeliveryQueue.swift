import Foundation

/// The aggregate identifier is one channel: a suspended older failure must
/// finish before a later workout-complete request replaces it.
actor UploadNotificationDeliveryQueue {
  static let shared = UploadNotificationDeliveryQueue()

  private var tail: Task<Void, Never>?
  private var revision = 0

  func perform(_ operation: @escaping @Sendable () async -> Void) async {
    revision += 1
    let revision = self.revision
    let previous = tail
    let task = Task {
      await previous?.value
      await operation()
    }
    tail = task
    await task.value
    if self.revision == revision { tail = nil }
  }
}
