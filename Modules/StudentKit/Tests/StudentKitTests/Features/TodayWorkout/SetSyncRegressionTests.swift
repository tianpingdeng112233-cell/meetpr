import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncRegressionTests {
  @Test func restoringQueuePrunesOnlyReceiptsOlderThanFourteenDays() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let calendar = WorkoutDatePolicy.deviceCalendar
    let today = try #require(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()))
    let expired = try #require(calendar.date(byAdding: .day, value: -15, to: today))
    let boundary = try #require(calendar.date(byAdding: .day, value: -14, to: today))
    let day = UUID()
    try queue.enqueue(
      dayID: day, trainingDate: expired, draft: SetSyncQueueTests.draft(), recordedAt: expired)
    try queue.enqueue(
      dayID: day, trainingDate: boundary, draft: SetSyncQueueTests.draft(), recordedAt: boundary)
    await queue.drain()
    try queue.enqueue(
      dayID: day, trainingDate: expired, draft: SetSyncQueueTests.draft(), recordedAt: expired)
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(restored.records.count == 2)
    #expect(restored.pendingCount == 1)
    #expect(
      restored.records.filter(\.synced).map(\.loggedDate) == [
        TodayWorkoutViewModel.gymDate(boundary, calendar: calendar)
      ])
    let again = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    #expect(again.records.count == 2)
  }

  @Test func serverSnapshotRemovesAcknowledgedReceiptDurably() async throws {
    let storage = MemorySetSyncStorage()
    let student = UUID()
    let queue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    let day = UUID()
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: SetSyncQueueTests.draft())
    await queue.drain()
    let server = try #require(queue.records.first?.draft)
    let projected = queue.overlay(dayID: day, drafts: [server])
    #expect(projected.first?.loggedSetID == server.loggedSetID)
    #expect(queue.records.isEmpty)
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(restored.records.isEmpty)
  }

  @Test func editingExistingPlannedSetKeepsItsLoggedDate() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let student = StudentDemoSeed.studentID
    let log = StudentSetLog(
      id: UUID(), studentID: student,
      planExerciseID: day.exercises[0].id, setIndex: 0, loggedAt: day.scheduledDate,
      loggedDate: "2026-01-01", weightKg: 100, reps: 3, completed: true)
    let logs = InMemoryStudentTrainingLogRepository(seed: [log])
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [student: plan])), logs: logs, setSyncQueue: queue)
    await model.load(dayID: day.id, studentID: student)
    #expect(model.currentDrafts?.first?.loggedSetID == log.id)
    #expect(await model.commitSet(rowIndex: 0))
    #expect(queue.records.first?.loggedDate == "2026-01-01")
  }

  @Test func queuedExtraCancellationRepairsDerivedHistory() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let student = StudentDemoSeed.studentID
    let logs = InMemoryStudentTrainingLogRepository()
    let e1rm = InMemoryE1RMRepository()
    let sender = SetSyncSender(logs: logs)
    let queue = try SetSyncQueue(
      studentID: student, storage: MemorySetSyncStorage(), send: sender.send)
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [student: plan])), logs: logs, e1rm: e1rm,
      setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    let exercise = plan.days[0].exercises[0]
    model.addExtraSet(exerciseID: exercise.id)
    let index = try #require(model.currentDrafts?.firstIndex { $0.isExtra })
    model.updateWeight(rowIndex: index, weight: 100)
    model.updateReps(rowIndex: index, reps: 3)
    model.updateRPE(rowIndex: index, rpe: 8)
    #expect(await model.commitSet(rowIndex: index))
    await queue.drain()
    #expect(
      try await e1rm.fetchHistory(studentId: student, exerciseId: exercise.exercise.id).count == 1)
    await model.toggleComplete(rowIndex: index)
    await queue.drain()
    #expect(
      try await e1rm.fetchHistory(studentId: student, exerciseId: exercise.exercise.id).isEmpty)
    #expect(try await e1rm.prEvents(studentId: student, since: .distantPast).isEmpty)
  }

  @Test func sameAddedSlotKeepsOriginalDateAcrossMidnight() throws {
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let day = UUID()
    var draft = SetSyncQueueTests.draft()
    draft.studentAddedDayID = day
    let first = Date(timeIntervalSince1970: 1_700_000_000)
    try queue.enqueue(dayID: day, trainingDate: first, draft: draft, recordedAt: first)
    try queue.enqueue(
      dayID: day, trainingDate: first, draft: draft,
      recordedAt: first.addingTimeInterval(172_800))
    #expect(Set(queue.records.map(\.loggedDate)).count == 1)
  }

  @Test func acknowledgedOverlayDoesNotOverwriteNewPrescription() async throws {
    let queue = try SetSyncQueue(studentID: UUID(), storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let day = UUID()
    var draft = SetSyncQueueTests.draft()
    draft.actualWeight = 100
    draft.completed = true
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: draft)
    await queue.drain()
    var server = try #require(queue.records.first?.draft)
    server.prescribed = PrescribedSet(id: UUID(), setIndex: 0, reps: 9)
    let confirmed = queue.overlay(dayID: day, drafts: [server])
    #expect(confirmed.first?.prescribed.reps == 9)
    server.actualWeight = 110
    #expect(queue.overlay(dayID: day, drafts: [server]).first?.actualWeight == 110)
  }

  @Test func twoDeletedPlanSlotsDoNotOverwriteSameAddedSlot() async throws {
    let logs = OfflineSetTestRepository(missing: true)
    let day = UUID()
    let sender = SetSyncSender(logs: logs, plans: SetSyncPlanFixture(dayID: day))
    let queue = try SetSyncQueue(
      studentID: UUID(), storage: MemorySetSyncStorage(), send: sender.send)
    let first = SetSyncQueueTests.draft()
    let second = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(),
      exerciseID: first.exerciseID, exerciseName: "Bench", isAccessory: false,
      prescribed: PrescribedSet(id: UUID(), setIndex: 0, reps: 5))
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: first)
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: second)
    await queue.drain()
    let added = await logs.added
    #expect(added.count == 2)
    #expect(Set(added.map(\.setIndex)).count == 2)
    let projected = queue.overlay(dayID: day, drafts: [])
    #expect(Set(projected.map(\.prescribed.setIndex)) == [0, 1])
    let cached = queue.overlay(dayID: day, drafts: [first, second])
    #expect(cached.allSatisfy { $0.isStudentAdded })
    #expect(Set(cached.map(\.prescribed.setIndex)) == [0, 1])
    #expect(queue.pendingCount == 0)
  }
}
