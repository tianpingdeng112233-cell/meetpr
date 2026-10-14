import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func changingFlexibleDayEndsRestAndPreservesRecordedSets() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let days = plan.days.filter { $0.completedAt == nil && $0.weekNumber == 1 }
  let first = try #require(days.first)
  let other = try #require(days.last)
  #expect(first.id != other.id)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: other.id, studentID: StudentDemoSeed.studentID)
  model.updateWeight(rowIndex: 0, weight: 80)
  model.updateReps(rowIndex: 0, reps: 3)
  #expect(await model.commitSet(rowIndex: 0))
  #expect(model.restTimer != nil)
  await model.load(dayID: first.id, studentID: StudentDemoSeed.studentID)
  #expect(model.restTimer == nil)
  await model.load(dayID: other.id, studentID: StudentDemoSeed.studentID)
  #expect(model.currentDrafts?.first?.completed == true)
  #expect(model.currentDrafts?.first?.actualWeight == 80)
}

@MainActor
@Test func addedWorkoutWritesExtraAndDayBoundAdhocAndDeletes() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let day = try #require(StudentPlanSequence(days: plan.days).cursorDay)
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let planned = try #require(day.exercises.first)
  model.addExtraSet(exerciseID: planned.id)
  let extra = try #require(model.currentDrafts?.last(where: { $0.isExtra }))
  let index = try #require(model.currentDrafts?.firstIndex(where: { $0.id == extra.id }))
  model.updateWeight(rowIndex: index, weight: 80)
  model.updateReps(rowIndex: index, reps: 3)
  #expect(await model.commitSet(rowIndex: index))
  #expect(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID,
      planExerciseID: planned.id
    ).last?.setIndex == planned.prescribedSets.count)
  let exercise = try #require(
    plan.days.flatMap(\.exercises).first { candidate in
      !day.exercises.contains { $0.exercise.id == candidate.exercise.id }
    }?.exercise ?? plan.days.last?.exercises.last?.exercise)
  model.addStudentExercise(exercise)
  let added = try #require(model.currentDrafts?.first(where: { $0.isStudentAdded }))
  var row = AccessoryRow(draft: added, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "50", reps: "5", rpe: "")
  #expect(await model.saveAccessoryRow(row))
  let fetched = try await logs.fetchAllLogs(
    studentID: StudentDemoSeed.studentID,
    in: Date.distantPast...Date.distantFuture)
  #expect(fetched.added.first?.planDayID == day.id)
  #expect(fetched.added.first?.rpe == nil)
  #expect(await model.removeStudentRow(id: added.id))
  #expect(
    try await logs.fetchAllLogs(
      studentID: StudentDemoSeed.studentID,
      in: Date.distantPast...Date.distantFuture
    ).added.isEmpty)
}

@MainActor
@Test func addedCancellationDoesNotRepeatCompletionFeedback() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let day = try #require(StudentPlanSequence(days: plan.days).cursorDay)
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  model.addStudentExercise(exercise)
  let initial = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = AccessoryRow(draft: initial, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "40", reps: "5", rpe: "")
  #expect(await model.saveAccessoryRow(row))
  #expect(model.inlineCompletionFeedback == 1)
  let saved = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  #expect(await model.saveAccessoryRow(AccessoryRow(draft: saved, previous: nil, unit: .kg)))
  #expect(model.inlineCompletionFeedback == 1)
}

@MainActor
@Test func addedRowsRestoreOwnerAndPinnedDateAcrossDaySwitch() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let days = plan.days.filter { $0.completedAt == nil && $0.weekNumber == 1 }
  let day = try #require(days.last)
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  let now = Date()
  let log = StudentAddedSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: day.id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: now,
    loggedDate: "2026-10-13", weightKg: 55, reps: 5, completed: true)
  let repository = InMemoryStudentTrainingLogRepository(added: [log])
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: repository)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  #expect(model.currentDrafts?.contains { $0.loggedSetID == log.id } == true)
  model.addStudentSet(exerciseID: exercise.id)
  let pending = try #require(model.currentDrafts?.last { $0.isStudentAdded })
  var row = AccessoryRow(draft: pending, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "60", reps: "6", rpe: "")
  #expect(await model.saveAccessoryRow(row))
  let saved = try await repository.fetchAllLogs(
    studentID: StudentDemoSeed.studentID,
    in: Date.distantPast...Date.distantFuture)
  #expect(saved.added.count == 2)
  #expect(Set(saved.added.compactMap(\.loggedDate)) == ["2026-10-13"])
}

@MainActor
@Test func deletingAddedSetRemovesItsE1RMAndPR() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let day = try #require(StudentPlanSequence(days: plan.days).cursorDay)
  let exercise = try #require(
    plan.days.flatMap(\.exercises).first { candidate in
      candidate.exercise.mainLiftFamily != nil
        && !day.exercises.contains { $0.exercise.id == candidate.exercise.id }
    }?.exercise)
  let e1rm = InMemoryE1RMRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository(), e1rm: e1rm)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  model.addStudentExercise(exercise)
  let initial = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = AccessoryRow(draft: initial, previous: nil, unit: .kg)
  row.input = AccessoryInput(weight: "100", reps: "3", rpe: "8")
  #expect(await model.saveAccessoryRow(row))
  #expect(
    try await e1rm.fetchHistory(studentId: StudentDemoSeed.studentID, exerciseId: exercise.id).count
      == 1)
  #expect(await model.removeStudentRow(id: initial.id))
  #expect(
    try await e1rm.fetchHistory(studentId: StudentDemoSeed.studentID, exerciseId: exercise.id)
      .isEmpty)
}

@MainActor
@Test func fullEntryRejectsOtherWeekWrites() async throws {
  let plan = StudentDemoSeed.makePlanView()
  let cursor = try #require(StudentPlanSequence(days: plan.days).cursorDay)
  let day = try #require(plan.days.first { $0.weekNumber != cursor.weekNumber })
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  #expect(await model.commitSet(rowIndex: 0) == false)
  #expect(
    try await logs.fetchLogs(
      studentID: StudentDemoSeed.studentID, in: .distantPast ... .distantFuture
    ).isEmpty)
}

@MainActor
@Test func addedExercisesAndRowsStopAtTenWithoutChangingPrescription() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  for _ in 0..<11 {
    model.addStudentExercise(
      Exercise(
        id: UUID(), name: "Added", exerciseType: .accessory, isCompetitionLift: false,
        muscleGroups: [], equipment: [], createdAt: Date()))
  }
  #expect(Set((model.currentDrafts ?? []).filter(\.isStudentAdded).map(\.exerciseID)).count == 10)
  let exercise = try #require(model.currentDrafts?.first { $0.isStudentAdded }?.exerciseID)
  for _ in 0..<11 { model.addStudentSet(exerciseID: exercise) }
  #expect(model.currentDrafts?.count { $0.isStudentAdded && $0.exerciseID == exercise } == 10)
  guard case .loaded(let day, _) = model.state else {
    Issue.record("Expected loaded day")
    return
  }
  #expect(day.exercises == plan.days[0].exercises)
}

@MainActor
@Test func addedPreviousRecordCanFillWeightAndRepsWithoutRPE() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = try #require(plan.days.last?.exercises.last?.exercise)
  let log = StudentAddedSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: plan.days[1].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date().addingTimeInterval(-86_400),
    weightKg: 32.5, reps: 12, rpe: 8, completed: true)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository(added: [log]))
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  model.addStudentExercise(exercise)
  let draft = try #require(model.currentDrafts?.first { $0.isStudentAdded })
  var row = model.studentAddedInput(draft: draft, unit: .kg)
  row.usePrevious()
  #expect(row.weightKg == 32.5)
  #expect(row.reps == 12)
  #expect(row.rpe == nil)
}

@MainActor
@Test func deletedHighestAddedWeightRestoresNonPRBaseline() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = try #require(plan.days[0].exercises.first?.exercise)
  let student = StudentDemoSeed.studentID
  let kept = StudentAddedSetLog(
    id: UUID(), studentID: student, planDayID: plan.days[0].id, exerciseID: exercise.id,
    setIndex: 0, loggedAt: Date(), weightKg: 100, reps: 1, completed: true)
  let removedID = UUID()
  let repository = InMemoryE1RMRepository()
  try await repository.recordWeightBaseline(
    E1RMWeightBaseline(
      studentId: student, family: .squat, maxWeightKg: 120,
      setLogId: removedID, achievedAt: Date()))
  let replacements = StudentAddedDerivedHistory.baselines(
    StudentWorkoutLogs(planned: [], added: [kept]), days: plan.days, catalog: [exercise])
  try await StudentAddedDerivedHistory.remove(
    setID: removedID, studentID: student, exerciseIDs: [exercise.id], repository: repository,
    replacementBaselines: replacements)
  #expect(try await repository.fetchWeightBaselines(studentId: student).first?.maxWeightKg == 100)
}

@MainActor
@Test func extraCancellationRemovesE1RMAndPR() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let e1rm = InMemoryE1RMRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository(), e1rm: e1rm)
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  let exercise = plan.days[0].exercises[0]
  model.addExtraSet(exerciseID: exercise.id)
  let index = try #require(model.currentDrafts?.firstIndex { $0.isExtra })
  model.updateWeight(rowIndex: index, weight: 100)
  model.updateReps(rowIndex: index, reps: 3)
  model.updateRPE(rowIndex: index, rpe: 8)
  #expect(await model.commitSet(rowIndex: index))
  #expect(
    try await e1rm.fetchHistory(
      studentId: StudentDemoSeed.studentID, exerciseId: exercise.exercise.id
    ).count == 1)
  await model.toggleComplete(rowIndex: index)
  #expect(
    try await e1rm.fetchHistory(
      studentId: StudentDemoSeed.studentID, exerciseId: exercise.exercise.id
    ).isEmpty)
  #expect(
    try await e1rm.prEvents(studentId: StudentDemoSeed.studentID, since: .distantPast).isEmpty)
}

@MainActor
@Test func authoritativeLedgerRepairsDeletedSourceAfterReopening() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = plan.days[0].exercises[0].exercise
  let student = StudentDemoSeed.studentID
  let repository = InMemoryE1RMRepository()
  let stale = StudentAddedSetLog(
    id: UUID(), studentID: student, planDayID: plan.days[0].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 100, reps: 3, rpe: 8,
    completed: true)
  await StudentAddedHistory.record([stale], catalog: [exercise], e1rm: repository, profile: nil)
  #expect(try await repository.fetchHistory(studentId: student, exerciseId: exercise.id).count == 1)
  try await StudentAddedLedgerRepair.reconcile(
    source: .init(
      records: StudentWorkoutLogs(
        planned: [], added: [], isAuthoritative: false, isCompleteLedger: true),
      revision: try await repository.historySnapshot(studentId: student, exerciseIds: []).revision),
    studentID: student, days: plan.days, catalog: [exercise], profile: nil, repository: repository)
  #expect(try await repository.fetchHistory(studentId: student, exerciseId: exercise.id).count == 1)
  try await StudentAddedLedgerRepair.reconcile(
    source: .init(
      records: StudentWorkoutLogs(planned: [], added: [], isCompleteLedger: true),
      revision: try await repository.historySnapshot(studentId: student, exerciseIds: []).revision),
    studentID: student, days: plan.days, catalog: [exercise], profile: nil, repository: repository)
  #expect(try await repository.fetchHistory(studentId: student, exerciseId: exercise.id).isEmpty)
  #expect(try await repository.prEvents(studentId: student, since: .distantPast).isEmpty)
  #expect(try await repository.fetchWeightBaselines(studentId: student).isEmpty)
}

@MainActor
@Test func staleLedgerCannotEraseASetSavedWhileItWasBeingFetched() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = plan.days[0].exercises[0].exercise
  let student = StudentDemoSeed.studentID
  let repository = InMemoryE1RMRepository()
  let revision = try await repository.historySnapshot(studentId: student, exerciseIds: []).revision
  let staleLedger = StudentWorkoutLogs(planned: [], added: [], isCompleteLedger: true)
  let newLog = StudentAddedSetLog(
    id: UUID(), studentID: student, planDayID: plan.days[0].id,
    exerciseID: exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 100, reps: 3, rpe: 8,
    completed: true)
  await StudentAddedHistory.record([newLog], catalog: [exercise], e1rm: repository, profile: nil)
  try? await StudentAddedLedgerRepair.reconcile(
    source: .init(records: staleLedger, revision: revision), studentID: student, days: plan.days,
    catalog: [exercise],
    repository: repository)
  #expect(try await repository.fetchHistory(studentId: student, exerciseId: exercise.id).count == 1)
}
