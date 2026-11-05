import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncReceiptTests {
  @Test func convertedReceiptWithOldPlanAndRestoredAddedRowHasOneIdentity() async throws {
    let logs = OfflineSetTestRepository(missing: true)
    let day = UUID()
    let sender = SetSyncSender(logs: logs, plans: SetSyncPlanFixture(dayID: day))
    let queue = try SetSyncQueue(
      studentID: UUID(), storage: MemorySetSyncStorage(), send: sender.send)
    let oldPlanRow = SetSyncQueueTests.draft()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: oldPlanRow)
    await queue.drain()
    let receipt = try #require(queue.overlay(dayID: day, drafts: []).first)
    var restored = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: receipt.exerciseID, exerciseID: receipt.exerciseID,
      exerciseName: receipt.exerciseName, isAccessory: receipt.isAccessory,
      prescribed: receipt.prescribed)
    restored.studentAddedDayID = day
    restored.loggedSetID = receipt.loggedSetID

    let rows = queue.overlay(dayID: day, drafts: [oldPlanRow, restored])

    let loggedIDs = rows.compactMap(\.loggedSetID)
    #expect(Set(loggedIDs).count == loggedIDs.count)
    #expect(rows.count == 1)
    // Either input on its own is already handled: the overlap causes the failure.
    #expect(queue.overlay(dayID: day, drafts: [oldPlanRow]).count == 1)
    #expect(queue.overlay(dayID: day, drafts: [restored]).count == 1)
    #expect(rows.first?.isStudentAdded == true)
    #expect(rows.first?.loggedSetID == restored.loggedSetID)
  }

  @Test func reopeningConvertedDayWithCachedPlanKeepsOneRowPerRecord() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let logs = OfflineSetTestRepository(missing: true)
    let sender = SetSyncSender(logs: logs, plans: SetSyncPlanFixture(dayID: day.id))
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: logs, setSyncQueue: queue)
    await model.load(dayID: day.id, studentID: student, preloadedPlan: plan)
    let original = try #require(model.currentDrafts)
    let recorded = try #require(original.first)
    model.updateWeight(rowIndex: 0, weight: 100)
    model.updateReps(rowIndex: 0, reps: 3)
    #expect(await model.commitSet(rowIndex: 0))
    await queue.drain()
    let log = try #require(await logs.added.first)

    // Returning to the day supplies its cached plan alongside refreshed added logs.
    await model.load(dayID: day.id, studentID: student, preloadedPlan: plan)
    let reopened = try #require(model.currentDrafts)
    let identities = reopened.map { $0.loggedSetID ?? $0.id }
    #expect(Set(identities).count == identities.count)
    #expect(reopened.count == original.count)
    let added = try #require(reopened.first { $0.loggedSetID == log.id })
    #expect(added.isStudentAdded)
    #expect(added.actualWeight == 100)
    #expect(added.actualReps == 3)
    #expect(
      !reopened.contains {
        !$0.isStudentAdded && $0.planExerciseID == recorded.planExerciseID
          && $0.prescribed.setIndex == recorded.prescribed.setIndex
      })
  }

  @Test func staleMatchingSnapshotCannotRetireTheLatestReceipt() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let day = UUID()
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    var draft = SetSyncQueueTests.draft()
    let first = Date()
    draft.actualWeight = 100
    try queue.enqueue(dayID: day, trainingDate: first, draft: draft, recordedAt: first)
    await queue.drain()
    let oldMatching = try #require(queue.records.first?.draft)
    draft.actualWeight = 110
    try queue.enqueue(
      dayID: day, trainingDate: first, draft: draft, recordedAt: first.addingTimeInterval(1))
    await queue.drain()
    let oldDifferent = try #require(queue.records.first?.draft)
    draft.actualWeight = 100
    try queue.enqueue(
      dayID: day, trainingDate: first, draft: draft, recordedAt: first.addingTimeInterval(2))
    await queue.drain()
    let latest = try #require(queue.records.first?.draft)
    _ = queue.overlay(dayID: day, drafts: [oldMatching])
    #expect(queue.records.count == 1)
    #expect(queue.overlay(dayID: day, drafts: [oldDifferent]).first?.actualWeight == 100)
    _ = queue.overlay(dayID: day, drafts: [latest])
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(restored.records.isEmpty)
  }
}
