import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncCompletionTests {
  @Test func emptyQueueGoesStraightToReward() async throws {
    let queue = try makeQueue()
    let coordinator = SetSyncCompletionCoordinator(queue: queue)
    #expect(await coordinator.prepare(dayID: UUID()))
    #expect(coordinator.phase == .idle)
  }

  @Test func timeoutDoesNotRewardAndRetryStartsNewDeadline() async throws {
    let clock = SetSyncTestClock()
    let queue = try makeQueue()
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    let coordinator = SetSyncCompletionCoordinator(queue: queue, sleep: { await clock.sleep() })
    let attempt = Task { await coordinator.prepare(dayID: day) }
    await clock.waitUntilSleeping()
    #expect(coordinator.phase == .syncing)
    clock.advance()
    #expect(!(await attempt.value))
    #expect(coordinator.phase == .failed)
    let retry = Task { await coordinator.prepare(dayID: day, retry: true) }
    await clock.waitUntilSleeping()
    #expect(coordinator.phase == .syncing)
    await queue.drain()
    #expect(await retry.value)
    #expect(coordinator.phase == .idle)
    clock.advance()
  }

  @Test func rejectionFailsImmediatelyAndLeavingResets() async throws {
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { _ in
      throw SetSyncFailure.rejected
    }
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    await queue.drain()
    let coordinator = SetSyncCompletionCoordinator(queue: queue)
    #expect(!(await coordinator.prepare(dayID: day)))
    #expect(coordinator.phase == .failed)
    coordinator.reset()
    #expect(coordinator.phase == .idle)
  }

  @Test func durableGateRequiresBothInputsAndCallsCompletionOnce() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let day = UUID()
    let gate = try WorkoutCompletionGate(studentID: student, storage: storage)
    try gate.request(dayID: day)
    var calls = 0
    let complete: @MainActor () async throws -> PlanDayCompletion = {
      calls += 1
      return PlanDayCompletion(
        id: UUID(), dayID: day, studentID: student,
        source: "manual", completedAt: Date())
    }
    #expect(
      try await gate.completeIfReady(
        dayID: day, setsSynced: false,
        videosDelivered: true, complete: complete) == nil)
    #expect(
      try await gate.completeIfReady(
        dayID: day, setsSynced: true,
        videosDelivered: false, complete: complete) == nil)
    let restored = try WorkoutCompletionGate(studentID: student, storage: storage)
    #expect(restored.pendingDays == [day])
    #expect(
      try await restored.completeIfReady(
        dayID: day, setsSynced: true,
        videosDelivered: true, complete: complete) != nil)
    #expect(
      try await restored.completeIfReady(
        dayID: day, setsSynced: true,
        videosDelivered: true, complete: complete) == nil)
    #expect(calls == 1)
    let saved = try #require(storage.read(account: student, name: "completion"))
    #expect(try JSONSerialization.jsonObject(with: saved) as? [AnyHashable] == [])
  }

  private func makeQueue() throws -> SetSyncQueue {
    try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { .planned($0.plannedLog) }
  }
}

@MainActor final class SetSyncTestClock {
  private var sleepers: [CheckedContinuation<Void, Never>] = []
  private var observers: [CheckedContinuation<Void, Never>] = []
  func sleep() async {
    await withCheckedContinuation { continuation in
      sleepers.append(continuation)
      for continuation in observers { continuation.resume() }
      observers = []
    }
  }
  func waitUntilSleeping() async {
    if !sleepers.isEmpty { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func advance() {
    let current = sleepers
    sleepers = []
    for continuation in current { continuation.resume() }
  }
}

@MainActor func waitForSetSync(_ condition: @MainActor () -> Bool) async throws {
  for _ in 0..<200 {
    if condition() { return }
    try await Task.sleep(for: .milliseconds(5))
  }
  Issue.record("Set sync condition did not finish")
}
