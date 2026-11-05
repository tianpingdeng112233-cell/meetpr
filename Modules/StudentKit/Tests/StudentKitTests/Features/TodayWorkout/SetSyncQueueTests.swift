import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncQueueTests {
  @Test func durableQueueRestoresLatestEditAndKeepsAccountsSeparate() throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let day = UUID()
    let draft = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "Bench",
      isAccessory: false, prescribed: PrescribedSet(id: UUID(), setIndex: 0, reps: 5))
    let queue = try SetSyncQueue(
      studentID: student, storage: storage, send: { .planned($0.plannedLog) })
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: draft)
    var edited = draft
    edited.completed = true
    edited.actualWeight = 105
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: edited)
    let restored = try SetSyncQueue(
      studentID: student, storage: storage, send: { .planned($0.plannedLog) })
    #expect(restored.pendingCount == 2)
    #expect(restored.overlay(dayID: day, drafts: [draft]).first?.completed == true)
    #expect(restored.overlay(dayID: day, drafts: [draft]).first?.actualWeight == 105)
    let other = try SetSyncQueue(
      studentID: UUID(), storage: storage, send: { .planned($0.plannedLog) })
    #expect(other.pendingCount == 0)
  }
  @Test func sendsInOrderAndLastCancellationWins() async throws {
    var sent: [Bool] = []
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { record in
      sent.append(record.draft.completed)
      return .planned(record.plannedLog)
    }
    let day = UUID()
    var draft = Self.draft()
    draft.completed = true
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: draft)
    draft.completed = false
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: draft)
    await queue.drain()
    #expect(sent == [true, false])
    #expect(queue.pendingCount == 0)
    #expect(queue.overlay(dayID: day, drafts: []).first?.completed == false)
  }

  @Test func transientFailureKeepsLocalStateThenRetries() async throws {
    var calls = 0
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { record in
      calls += 1
      if calls == 1 { throw URLError(.notConnectedToInternet) }
      return .planned(record.plannedLog)
    }
    let day = UUID()
    var draft = Self.draft()
    draft.completed = true
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: draft)
    await queue.drain()
    #expect(queue.pendingCount == 1)
    #expect(queue.overlay(dayID: day, drafts: []).first?.completed == true)
    await queue.drain()
    #expect(queue.pendingCount == 0)
  }

  @Test func rejectedRecordStopsUntilExplicitRetry() async throws {
    var calls = 0
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { record in
      calls += 1
      if calls == 1 { throw SetSyncFailure.rejected }
      return .planned(record.plannedLog)
    }
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: .distantPast, draft: Self.draft())
    await queue.drain()
    await queue.drain()
    #expect(calls == 1)
    #expect(queue.hasRejected(dayID: day))
    queue.retryNow(dayID: day)
    await queue.drain()
    #expect(calls == 2)
    #expect(queue.pendingCount == 0)
  }

  @Test func immediateDayHasPriorityAndStopPreservesRecords() async throws {
    var days: [UUID] = []
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) { record in
      days.append(record.dayID)
      return .planned(record.plannedLog)
    }
    let first = UUID()
    let second = UUID()
    try queue.enqueue(dayID: first, trainingDate: .distantPast, draft: Self.draft())
    try queue.enqueue(dayID: second, trainingDate: .distantPast, draft: Self.draft())
    queue.retryNow(dayID: second)
    await queue.drain()
    #expect(days == [second, first])
    try queue.enqueue(dayID: first, trainingDate: .distantPast, draft: Self.draft())
    queue.stop()
    await queue.drain()
    #expect(queue.pendingCount == 1)
  }

  static func draft() -> TodayWorkoutSetRowDraft {
    TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: UUID(), exerciseName: "Bench",
      isAccessory: false, prescribed: PrescribedSet(id: UUID(), setIndex: 0, reps: 5))
  }

}
