import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncDraftTests {
  @Test func attachingVideoPromotesAnUnfilledRowToASendableRecord() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let model = TodayWorkoutViewModel(
      plans: plans, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    model.addExtraSet(exerciseID: plan.days[0].exercises[0].id)
    let index = try #require(model.currentDrafts?.firstIndex { $0.isExtra })
    #expect(await model.ensureLoggedSetID(rowIndex: index) == nil)
    #expect(queue.pendingCount == 1)
    await queue.drain()
    #expect(await model.ensureLoggedSetID(rowIndex: index) != nil)
  }

  @Test func oldAcknowledgementCannotTurnAReusedEmptySlotIntoASavedRow() async throws {
    let student = UUID()
    let day = UUID()
    let storage = MemorySetSyncStorage()
    let queue = try SetSyncQueue(studentID: student, storage: storage) {
      $0.deleting ? .deleted : .planned($0.plannedLog)
    }
    var saved = SetSyncQueueTests.draft()
    saved.isExtra = true
    saved.recordedAt = Date()
    saved.completed = true
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: saved)
    try queue.enqueue(dayID: day, trainingDate: Date(), draft: saved, deleting: true)
    let empty = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: saved.planExerciseID, exerciseID: saved.exerciseID,
      exerciseName: saved.exerciseName, isAccessory: true, prescribed: saved.prescribed)
    try queue.storeDraft(dayID: day, trainingDate: Date(), draft: empty)
    await queue.drain()
    let reopened = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    let rows = reopened.overlay(dayID: day, drafts: [])
    #expect(rows.count == 1)
    #expect(rows.first?.id == empty.id)
    #expect(rows.first?.hasSavedRecord == false)
    #expect(rows.first?.loggedSetID == nil)
  }

  @Test func unfilledEditsAndRemovalPersistWithoutEnteringTheSendQueue() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = InMemoryStudentTrainingLogRepository()
    let storage = MemorySetSyncStorage()
    var sends = 0
    let queue = try SetSyncQueue(studentID: student, storage: storage) {
      sends += 1
      return .planned($0.plannedLog)
    }
    let model = TodayWorkoutViewModel(plans: plans, logs: logs, setSyncQueue: queue)
    await model.load(dayID: day.id, studentID: student)
    model.addExtraSet(exerciseID: day.exercises[0].id)
    let index = try #require(model.currentDrafts?.firstIndex { $0.isExtra })
    model.updateWeight(rowIndex: index, weight: 95)
    model.updateReps(rowIndex: index, reps: 7)
    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    let row = try #require(restored.overlay(dayID: day.id, drafts: []).first)
    #expect(row.actualWeight == 95)
    #expect(row.actualReps == 7)
    #expect(!row.hasSavedRecord)
    let other = try SetSyncQueue(studentID: UUID(), storage: storage) { .planned($0.plannedLog) }
    #expect(other.overlay(dayID: day.id, drafts: []).isEmpty)
    #expect(await model.removeStudentRow(id: row.id))
    await queue.drain()
    #expect(sends == 0)
    let afterRemoval = try SetSyncQueue(studentID: student, storage: storage) {
      .planned($0.plannedLog)
    }
    #expect(afterRemoval.overlay(dayID: day.id, drafts: []).isEmpty)
  }

  @Test func unfilledAddedRowsRestoreWithoutSendingOrLockingEffort() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let logs = InMemoryStudentTrainingLogRepository()
    let storage = MemorySetSyncStorage()
    var sent: [PendingSetRecord] = []
    let queue = try SetSyncQueue(studentID: student, storage: storage) {
      sent.append($0)
      return .planned($0.plannedLog)
    }
    let model = TodayWorkoutViewModel(plans: plans, logs: logs, setSyncQueue: queue)
    await model.load(dayID: day.id, studentID: student)
    let accessory = Exercise(
      id: UUID(), name: "Cable pushdown", exerciseType: .accessory, isCompetitionLift: false,
      muscleGroups: [], equipment: [], createdAt: Date())
    model.addExtraSet(exerciseID: day.exercises[0].id)
    model.addStudentExercise(accessory)
    model.addStudentSet(exerciseID: accessory.id)
    let created = try #require(model.currentDrafts?.filter { $0.isExtra || $0.isStudentAdded })
    #expect(created.count == 3)
    #expect(created.allSatisfy { !$0.hasSavedRecord })
    #expect(queue.pendingCount == 0)
    #expect(queue.pendingSetCount == 0)
    await queue.drain()
    #expect(sent.isEmpty)

    let restored = try SetSyncQueue(studentID: student, storage: storage) {
      sent.append($0)
      return .planned($0.plannedLog)
    }
    let reopened = TodayWorkoutViewModel(plans: plans, logs: logs, setSyncQueue: restored)
    await reopened.load(dayID: day.id, studentID: student)
    let rows = try #require(reopened.currentDrafts?.filter { $0.isExtra || $0.isStudentAdded })
    #expect(rows.count == 3)
    #expect(rows.allSatisfy { !$0.hasSavedRecord })
    let first = try #require(rows.first { $0.isStudentAdded })
    var input = AccessoryRow(draft: first, previous: nil, unit: .kg)
    input.switchEffort(to: .rir)
    #expect(input.input.effortMode == .rir)
    input.input.weight = "12.5"
    input.input.reps = "12"
    input.input.rpe = "2"
    #expect(await reopened.saveAccessoryRow(input))
    #expect(restored.pendingCount == 1)
    await restored.drain()
    #expect(sent.count == 1)
    #expect(sent.first?.draft.actualRIR == 2)
    #expect(sent.first?.draft.actualWeight == Decimal(string: "12.5"))
    let again = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
    #expect(again.overlay(dayID: day.id, drafts: []).count == 3)
  }
}
