import Foundation
import Observation

@Observable @MainActor final class SetSyncCompletionCoordinator {
  enum Phase { case idle, syncing, failed }

  private(set) var phase: Phase = .idle
  private let queue: SetSyncQueue
  private let sleep: @MainActor () async -> Void
  private var continuation: CheckedContinuation<Bool, Never>?
  private var timer: Task<Void, Never>?
  private var observer: UUID?
  private var dayID: UUID?

  init(
    queue: SetSyncQueue,
    sleep: @escaping @MainActor () async -> Void = { try? await Task.sleep(for: .seconds(20)) }
  ) {
    self.queue = queue
    self.sleep = sleep
  }

  func prepare(dayID: UUID, retry: Bool = false) async -> Bool {
    guard continuation == nil else { return false }
    guard queue.pendingCount(dayID: dayID) > 0 else {
      phase = .idle
      return true
    }
    if queue.hasRejected(dayID: dayID), !retry {
      phase = .failed
      return false
    }
    self.dayID = dayID
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      phase = .syncing
      observer = queue.observe { [weak self] in self?.evaluate() }
      timer = Task { [weak self, sleep] in
        await sleep()
        guard !Task.isCancelled else { return }
        self?.finish(success: false, phase: .failed)
      }
      queue.retryNow(dayID: dayID)
      evaluate()
    }
  }

  func reset() { finish(success: false, phase: .idle) }

  private func evaluate() {
    guard let dayID, continuation != nil else { return }
    if queue.hasRejected(dayID: dayID) {
      finish(success: false, phase: .failed)
    } else if queue.pendingCount(dayID: dayID) == 0 {
      finish(success: true, phase: .idle)
    }
  }

  private func finish(success: Bool, phase: Phase) {
    timer?.cancel()
    timer = nil
    if let observer { queue.removeObserver(observer) }
    observer = nil
    let waiting = continuation
    continuation = nil
    dayID = nil
    self.phase = phase
    waiting?.resume(returning: success)
  }
}
