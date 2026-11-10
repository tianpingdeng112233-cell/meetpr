import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func allDaySheetDoesNotInventUnprescribedEffort() async throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5)])
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [slot])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository(), now: { now })

  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)

  let row = try #require(model.currentDrafts?.first)
  #expect(row.actualWeight == 100)
  #expect(row.actualReps == 5)
  #expect(row.actualRPE == nil)
}

@MainActor
@Test func allDaySheetSavesEmptyWeightWithoutInventingZero() async throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8)])
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [slot])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, now: { now })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)

  #expect(await model.commitSet(rowIndex: 0))

  let recorded = try #require(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: slot.id
    ).first)
  #expect(recorded.weightKg == nil)
  #expect(recorded.reps == 5)
  #expect(recorded.rpe == 8)
}

@MainActor
@Test func allDaySheetExerciseCompletionCollapsesAndCancellationKeepsRecords() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let exercise = try #require(day.exercises.first)
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, now: { day.date.addingTimeInterval(43_200) })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  #expect(model.allDaySheet.first?.node == .current)
  #expect(await model.toggleAllDayExercise(exercise.id))
  #expect(model.allDaySheet.first?.node == .completed)
  #expect(model.allDaySheet.first?.isCollapsed == true)
  #expect(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: exercise.id
    ).count
      == exercise.prescribedSets.count)
  #expect(await model.toggleAllDayExercise(exercise.id))
  #expect(model.allDaySheet.first?.isCollapsed == false)
  #expect(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: exercise.id
    ).count
      == exercise.prescribedSets.count)
}

@MainActor
@Test func allDaySheetCompletionWritesUntouchedSetsAndPreservesEditedSet() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, now: { day.date.addingTimeInterval(43_200) })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  model.updateWeight(rowIndex: 0, weight: nil)
  model.updateReps(rowIndex: 0, reps: 4)
  #expect(await model.completeCurrentDay())
  let saved = try await logs.fetchLogs(
    studentID: StudentDemoSeed.studentID, in: Date.distantPast...Date.distantFuture)
  #expect(saved.count == day.exercises.flatMap(\.prescribedSets).count)
  let first = try #require(saved.first { $0.setIndex == 0 })
  #expect(first.weightKg == nil)
  #expect(first.reps == 4)
  #expect(model.restTimer == nil)
}

@MainActor
@Test func allDaySheetPrefillUsesRecordedThenPrescriptionThenMatchingSuggestion() throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let sets = [
    PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8),
    PrescribedSet(id: UUID(), setIndex: 1, reps: 5, rpe: 8),
    PrescribedSet(id: UUID(), setIndex: 2, reps: 5, rpe: 8),
    PrescribedSet(id: UUID(), setIndex: 3, weightKg: 120, reps: 5, rpe: 8),
  ]
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0, prescribedSets: sets)
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [slot])
  let old = StudentSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planExerciseID: slot.id,
    setIndex: 0, loggedAt: now, weightKg: nil, reps: 4, completed: true)
  let suggestions = [1, 3].map { index in
    SetWeightSuggestionRecord(
      planSetID: sets[index].id, weightKg: 102.5, sourceSetLogID: UUID(),
      sourceLoggedDate: "2026-01-01")
  }
  let rows = TodayWorkoutViewModel.makeDrafts(
    for: day, existingLogs: [old], suggestions: suggestions)
  #expect(rows.map(\.actualWeight) == [nil, 102.5, nil, 120])
  #expect(rows[0].actualReps == 4)
  #expect(rows[0].actualRPE == nil)
  #expect(rows[1].actualRPE == 8)
}

@MainActor
@Test func allDayUpgradeRestoresOldQueuedValuesAndKeepsNewEmptyWeights() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let student = StudentDemoSeed.studentID
  let storage = MemorySetSyncStorage()
  let oldQueue = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
  var rows = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  rows[0].actualWeight = 87.5
  rows[0].actualReps = 4
  rows[0].actualRPE = 8
  rows[0].completed = true
  try oldQueue.enqueue(dayID: day.id, trainingDate: day.scheduledDate, draft: rows[0])
  rows[1].actualWeight = nil
  rows[1].actualRPE = nil
  try oldQueue.enqueue(dayID: day.id, trainingDate: day.scheduledDate, draft: rows[1])
  let restored = try SetSyncQueue(studentID: student, storage: storage) { .planned($0.plannedLog) }
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
    logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: restored)
  await model.load(dayID: day.id, studentID: student)
  #expect(model.currentDrafts?[0].actualWeight == 87.5)
  #expect(model.currentDrafts?[0].actualReps == 4)
  #expect(model.currentDrafts?[0].actualRPE == 8)
  #expect(model.currentDrafts?[1].actualWeight == nil)
  #expect(model.currentDrafts?[1].actualRPE == nil)
  #expect(model.currentDrafts?[2].actualWeight == rows[2].prescribed.weightKg)
  await restored.drain()
  #expect(restored.pendingCount == 0)
  #expect(restored.records.first?.draft.actualWeight == 87.5)
}

@MainActor
@Test func allDayInlineEditingChangesOnlySelectedRowAndSurvivesDismissal() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])), logs: logs)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let drafts = try #require(model.currentDrafts)
  let keypad = WorkoutKeypadSession()
  keypad.openAllDay(draft: drafts[0], viewModel: model, field: .weight)
  keypad.update("102.5")
  keypad.dismiss()
  #expect(model.currentDrafts?[0].actualWeight == 102.5)
  #expect(model.currentDrafts?[1].actualWeight == drafts[1].actualWeight)
  #expect(keypad.current == nil)
}

@MainActor
@Test func allDayCompletionSkipsBlankAddedRowsAndAllowsEveryEmptyWeight() async throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [
      PrescribedSet(id: UUID(), setIndex: 0, loadMode: .freeWeight, reps: 5),
      PrescribedSet(id: UUID(), setIndex: 1, reps: 5, rpe: 8),
    ])
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [slot])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, now: { now })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let added = Exercise(
    id: UUID(), name: "Press", exerciseType: .accessory, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: now)
  model.addStudentExercise(added)
  #expect(model.completionWrites.count == 2)
  #expect(await model.completeCurrentDay())
  let saved = try await logs.fetchAllLogs(
    studentID: StudentDemoSeed.studentID, in: Date.distantPast...Date.distantFuture)
  #expect(saved.added.isEmpty)
  #expect(saved.planned.count == 2)
  #expect(saved.planned.allSatisfy { $0.weightKg == nil })
  #expect(model.completionPhase == .celebration)
}

@MainActor
@Test func allDayOfflineCompletionQueuesIntentAndKeepsRewardUntilReconnect() async throws {
  let student = StudentDemoSeed.studentID
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
  var offline = true
  let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) { record in
    if offline { throw URLError(.notConnectedToInternet) }
    return .planned(record.plannedLog)
  }
  let harness = VideoUploadHarness()
  let session = StudentSetSyncSession(
    queue: queue, plans: plans, videos: harness.manager, onLogout: {})
  defer { session.stop() }
  let model = TodayWorkoutViewModel(
    plans: plans, logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue,
    setSyncSleep: { try? await Task.sleep(for: .milliseconds(100)) })
  await model.load(dayID: day.id, studentID: student)
  queue.start()
  #expect(await model.completeCurrentDay())
  #expect(model.completionPhase == .celebration)
  #expect(queue.pendingCount > 0)
  #expect(queue.completionGate.pendingDays == [day.id])
  #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt == nil)
  offline = false
  await queue.drain()
  await queue.videoCompletion?.refresh()
  #expect(queue.pendingCount == 0)
  #expect(try await plans.fetchDay(studentID: student, dayID: day.id)?.completedAt != nil)
}
