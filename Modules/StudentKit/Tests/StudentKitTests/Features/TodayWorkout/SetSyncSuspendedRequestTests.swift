import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncSuspendedRequestTests {
  @Test func oldCompletionResponseCannotOverwriteNewLoginIntent() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let clock = SetSyncTestClock()
    let old = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let day = UUID()
    try old.completionGate.request(dayID: day)
    let sending = Task {
      try await old.completionGate.completeIfReady(
        dayID: day, setsSynced: true, videosDelivered: true
      ) {
        await clock.sleep()
        return PlanDayCompletion(
          id: UUID(), dayID: day, studentID: student, source: "manual", completedAt: Date())
      }
    }
    await clock.waitUntilSleeping()
    old.stop()
    let current = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let newDay = UUID()
    try current.completionGate.request(dayID: newDay)
    clock.advance()
    _ = try await sending.value
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(Set(restored.completionGate.pendingDays) == [day, newDay])
  }

  @Test func oldSetResponseCannotOverwriteNewLoginQueue() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let clock = SetSyncTestClock()
    let old = try SetSyncQueue(studentID: student, storage: storage) { record in
      await clock.sleep()
      return .planned(record.plannedLog)
    }
    try old.enqueue(dayID: UUID(), trainingDate: Date(), draft: SetSyncQueueTests.draft())
    let sending = Task { await old.drain() }
    await clock.waitUntilSleeping()
    old.stop()
    let current = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let newDay = UUID()
    try current.enqueue(dayID: newDay, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    clock.advance()
    await sending.value
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(restored.pendingCount(dayID: newDay) == 1)
    #expect(restored.pendingCount == 2)
  }

  @Test(.timeLimit(.minutes(1))) func suspendedRequestDoesNotBlockOtherRowsOrCommit() async throws {
    let logs = SuspendedSetSyncRepository()
    let fixture = try await accessoryFixture(logs: logs, includeFollowingMainLift: true)
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: StudentDemoSeed.studentID,
      storage: MemorySetSyncStorage(), send: sender.send)
    fixture.model.connectSetSync(queue)
    queue.start()
    let drafts = try #require(fixture.model.currentDrafts)
    #expect(
      await fixture.model.saveAccessoryRow(AccessoryRow(draft: drafts[0], previous: nil, unit: .kg))
    )
    await logs.waitUntilStarted()
    #expect(
      await fixture.model.saveAccessoryRow(AccessoryRow(draft: drafts[1], previous: nil, unit: .kg))
    )
    let main = try #require(drafts.firstIndex { !$0.isAccessory })
    #expect(await fixture.model.commitSet(rowIndex: main))
    #expect(fixture.model.currentDrafts?[0].completed == true)
    #expect(fixture.model.currentDrafts?[1].completed == true)
    #expect(fixture.model.currentDrafts?[main].completed == true)
    #expect(fixture.model.accessorySavingIDs.isEmpty)
    #expect(!fixture.model.accessoryBatchInFlight)
    #expect(queue.pendingCount == 3)
    await logs.release()
    try await waitForSetSync { queue.pendingCount == 0 }
    queue.stop()
  }
}

private actor SuspendedSetSyncRepository: StudentTrainingLogRepository {
  private var open = false
  private var started = false
  private var sleepers: [CheckedContinuation<Void, Never>] = []
  private var observers: [CheckedContinuation<Void, Never>] = []
  func recordSet(_ log: StudentSetLog) async -> StudentSetLog {
    started = true
    for continuation in observers { continuation.resume() }
    observers = []
    if !open { await withCheckedContinuation { sleepers.append($0) } }
    return log
  }
  func waitUntilStarted() async {
    if started { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    open = true
    for continuation in sleepers { continuation.resume() }
    sleepers = []
  }
  func fetchLogs(studentID: UUID, in range: ClosedRange<Date>) -> [StudentSetLog] { [] }
  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) -> [StudentSetLog] { [] }
}
