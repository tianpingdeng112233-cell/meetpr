import CoreModels
import DesignSystem
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
struct AllDayDirectEditingTests {
  @Test(arguments: [false, true])
  func warmupsNeverEnterVolumePRHistoryOrCompletionCounts(queued: Bool) async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let student = StudentDemoSeed.studentID
    let history = InMemoryE1RMRepository()
    let logs = InMemoryStudentTrainingLogRepository()
    let queue =
      queued
      ? try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
        .planned(try await logs.recordSet($0.plannedLog))
      } : nil
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: logs, e1rm: history, setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    let exercise = plan.days[0].exercises[0]
    let progress = TodayWorkoutProgress(day: plan.days[0], drafts: model.currentDrafts ?? [])
    let before = completionSnapshot(day: plan.days[0], model: model)
    let id = try #require(model.addWarmupSet(exerciseID: exercise.id))
    let index = try #require(model.currentDrafts?.firstIndex { $0.id == id })
    model.updateWeight(rowIndex: index, weight: 150)
    model.updateReps(rowIndex: index, reps: 5)
    model.updateRPE(rowIndex: index, rpe: 8)
    #expect(await model.saveAllDayRow(rowIndex: index, completed: true))
    await queue?.drain()
    #expect(TodayWorkoutProgress(day: plan.days[0], drafts: model.currentDrafts ?? []) == progress)
    let saved = try await logs.fetchLogsForExercise(studentID: student, planExerciseID: exercise.id)
    #expect(saved.count == 1)
    #expect(
      try await history.fetchHistory(studentId: student, exerciseId: exercise.exercise.id).isEmpty)
    #expect(try await history.prEvents(studentId: student, since: .distantPast).isEmpty)
    let replay = InMemoryE1RMRepository()
    await StudentAddedHistory.recordPlanned(
      saved, days: plan.days, catalog: [], e1rm: replay, profile: nil)
    #expect(
      try await replay.fetchHistory(studentId: student, exerciseId: exercise.exercise.id).isEmpty)
    #expect(ProgressMetrics.weeklyVolumeIntensity(from: saved).isEmpty)
    #expect(GrowthScreenPresentation.historyStats(logs: saved).totalVolumeKg == 0)
    #expect(
      TodayWorkoutViewModel.lastWeights(
        from: saved, planExerciseToExercise: [exercise.id: exercise.exercise.id]
      ).isEmpty)
    #expect(StudentAddedHistory.extraIndices(exercise: exercise, logs: saved).isEmpty)
    #expect(
      StudentAddedDerivedHistory.baselines(
        StudentWorkoutLogs(planned: saved, added: []), days: plan.days,
        catalog: [], profile: nil
      ).isEmpty)
    let after = completionSnapshot(day: plan.days[0], model: model)
    #expect(after == before)
  }

  private func completionSnapshot(
    day: StudentPlanDay, model: TodayWorkoutViewModel
  ) -> WorkoutCompletionPresentation {
    WorkoutCompletionPresentation(
      day: day, drafts: model.currentDrafts ?? [], references: [:],
      weekCode: "W1D1", coachName: nil)
  }

  @Test func addedRowRemembersOriginalWeightAndRestingRepsIsDirectlyEditable() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
    let group = try #require(model.allDaySheet.first)
    let last = try #require(group.rows.last)
    let index = try #require(model.currentDrafts?.firstIndex { $0.id == last.id })
    model.updateWeight(rowIndex: index, weight: 135)
    model.addExtraSet(exerciseID: group.id, copyLastVisible: true)
    let added = try #require(model.currentDrafts?.last)
    #expect(added.actualWeight == 135)
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: group.rows[1], viewModel: model, field: .weight)
    keypad.update("130")
    keypad.fillAllDay(.downward, viewModel: model)
    keypad.dismiss()
    let changed = try #require(model.currentDrafts?.first { $0.id == added.id })
    let row = AllDaySetRow(draft: changed, viewModel: model, editable: true, onVideo: {})
    let original = StudentStrings.replacing(.allDayOriginal, values: ["135"])
    #expect(try row.inspect().findAll(ViewType.Text.self).contains { try $0.string() == original })
    let reps = try row.inspect().find(viewWithAccessibilityIdentifier: "allDay.reps.\(changed.id)")
      .button()
    #expect(!reps.isDisabled())
  }

  @Test func switchingCellsKeepsLastLegalValueAndDoesNotSaveUntouchedRows() async throws {
    let seed = StudentAddedTestPlan.unsettledDemo()
    let seedDay = seed.days[0]
    let second = StudentPlanExercise(
      id: UUID(), exercise: seedDay.exercises[0].exercise, sequenceIndex: 1,
      prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, weightKg: 80, reps: 5)])
    let day = StudentPlanDay(
      id: seedDay.id, date: seedDay.date, exercises: seedDay.exercises + [second])
    let plan = StudentPlanView(
      cycleID: seed.cycleID, weekIndex: 1, startDate: seed.startDate, days: [day])
    let student = StudentDemoSeed.studentID
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    let rows = try #require(model.currentDrafts)
    let first = rows[0]
    let other = try #require(rows.first { $0.planExerciseID != first.planExerciseID })
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: first, viewModel: model, field: .weight)
    keypad.openAllDay(draft: other, viewModel: model, field: .weight)
    keypad.dismiss()
    #expect(queue.pendingCount == 0)
    keypad.openAllDay(draft: first, viewModel: model, field: .weight)
    keypad.update("130")
    keypad.update("")
    keypad.openAllDay(draft: other, viewModel: model, field: .reps)
    #expect(keypad.current?.rowID == other.id)
    #expect(model.currentDrafts?.first { $0.id == first.id }?.actualWeight == 130)
    keypad.update("0")
    keypad.openAllDay(draft: first, viewModel: model, field: .rpe)
    #expect(model.currentDrafts?.first { $0.id == other.id }?.actualReps == other.actualReps)
    keypad.update("8.5")
    keypad.update("3")
    keypad.openAllDay(draft: other, viewModel: model, field: .weight)
    #expect(model.currentDrafts?.first { $0.id == first.id }?.actualRPE == 8.5)
    keypad.openAllDay(draft: first, viewModel: model, field: .rpe)
    #expect(keypad.previewText == "8.5")
    keypad.dismiss()
  }

}

extension AllDayDirectEditingTests {
  @Test func fillCopiesOnlyOneFieldWithinTheCurrentSetKind() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let student = StudentDemoSeed.studentID
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: InMemoryStudentTrainingLogRepository(), setSyncQueue: queue)
    await model.load(dayID: plan.days[0].id, studentID: student)
    let group = try #require(model.allDaySheet.first)
    let warmupID = try #require(model.addWarmupSet(exerciseID: group.id))
    model.addExtraSet(exerciseID: group.id, copyLastVisible: true)
    let formal = try #require(model.allDaySheet.first?.rows.filter { !$0.isWarmup })
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: formal[1], viewModel: model, field: .weight)
    keypad.update("130")
    keypad.fillAllDay(.downward, viewModel: model)
    let after = try #require(model.allDaySheet.first?.rows.filter { !$0.isWarmup })
    #expect(after.dropFirst().map(\.actualWeight) == [130, 130, 130])
    #expect(after.map(\.actualReps) == formal.map(\.actualReps))
    #expect(after.map(\.actualRPE) == formal.map(\.actualRPE))
    #expect(model.currentDrafts?.first { $0.id == warmupID }?.actualWeight == nil)
    #expect(keypad.actionMessage != nil)
    keypad.update("125")
    #expect(keypad.actionMessage == nil)
    keypad.fillAllDay(.upward, viewModel: model)
    #expect(model.currentDrafts?.first { $0.id == formal[0].id }?.actualWeight == 125)
    keypad.update("")
    keypad.fillAllDay(.downward, viewModel: model)
    #expect(model.currentDrafts?.first { $0.id == formal[2].id }?.actualWeight == 130)
    keypad.openAllDay(draft: after[1], viewModel: model, field: .rpe)
    keypad.update("")
    keypad.fillAllDay(.downward, viewModel: model)
    #expect(model.currentDrafts?.first { $0.id == formal[2].id }?.actualRPE == nil)
    await Task.yield()
    #expect(queue.pendingCount > 0)
  }

  @Test func warmupSurvivesOfflineRestartAndCompletionDiscardsEmptyWeight() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let student = StudentDemoSeed.studentID
    let storage = MemorySetSyncStorage()
    let logs = InMemoryStudentTrainingLogRepository()
    let queue = try SetSyncQueue(studentID: student, storage: storage) { _ in
      throw URLError(.notConnectedToInternet)
    }
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: logs, setSyncQueue: queue)
    await model.load(dayID: day.id, studentID: student)
    let exercise = try #require(day.exercises.first)
    let firstID = try #require(model.addWarmupSet(exerciseID: exercise.id))
    let emptyID = try #require(model.addWarmupSet(exerciseID: exercise.id))
    let index = try #require(model.currentDrafts?.firstIndex { $0.id == firstID })
    model.updateWeight(rowIndex: index, weight: 20)
    #expect(await model.saveAllDayRow(rowIndex: index))
    let restored = try SetSyncQueue(studentID: student, storage: storage) { record in
      .planned(try await logs.recordSet(record.plannedLog))
    }
    let reloaded = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: logs, setSyncQueue: restored)
    await reloaded.load(dayID: day.id, studentID: student)
    #expect(reloaded.allDaySheet.first?.rows.prefix(2).allSatisfy { $0.isWarmup } == true)
    restored.start()
    defer { restored.stop() }
    #expect(await reloaded.completeCurrentDay())
    #expect(reloaded.currentDrafts?.contains { $0.id == emptyID } == false)
    await restored.drain()
    let saved = try await logs.fetchLogsForExercise(studentID: student, planExerciseID: exercise.id)
    #expect(saved.filter(\.isWarmup).count == 1)
    #expect(saved.first(where: \.isWarmup)?.weightKg == 20)
    let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: saved)
    let sheet = AllDayExercise.build(drafts: drafts, collapsed: [])
    #expect(sheet.first?.rows.first?.isWarmup == true)
    #expect(sheet.first?.rows.filter { !$0.isWarmup }.count == exercise.prescribedSets.count)
  }

  @Test func warmupsCopyOnlyPreviousWarmupAndKeepFormalSummaryAndSeparateLimits() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
    let first = try #require(model.allDaySheet.first)
    let summary = AllDayExerciseSummary.build(rows: first.rows)
    let initialCount = model.completionWrites.count
    let warmupID = try #require(model.addWarmupSet(exerciseID: first.id))
    let index = try #require(model.currentDrafts?.firstIndex { $0.id == warmupID })
    #expect(model.currentDrafts?[index].actualWeight == nil)
    #expect(model.currentDrafts?[index].actualReps == first.rows.first?.actualReps)
    model.updateWeight(rowIndex: index, weight: 20)
    model.updateReps(rowIndex: index, reps: 8)
    for _ in 0..<4 { #expect(model.addWarmupSet(exerciseID: first.id) != nil) }
    #expect(model.addWarmupSet(exerciseID: first.id) == nil)
    let rows = try #require(model.allDaySheet.first?.rows)
    #expect(rows.prefix(5).allSatisfy { $0.isWarmup })
    #expect(rows.prefix(5).map(\.actualWeight) == [20, 20, 20, 20, 20])
    #expect(rows.prefix(5).map(\.actualReps) == [8, 8, 8, 8, 8])
    #expect(rows.prefix(5).allSatisfy { $0.actualRPE == nil })
    #expect(AllDayExerciseSummary.build(rows: rows) == summary)
    #expect(model.completionWrites.filter { !$0.isWarmup }.count == initialCount)
    for _ in 0..<11 { model.addExtraSet(exerciseID: first.id) }
    #expect(
      model.currentDrafts?.filter { $0.planExerciseID == first.id && $0.isExtra && !$0.isWarmup }
        .count == 10)
  }

  @Test func keypadLeavesInlineFieldsReachable() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
    let draft = try #require(model.currentDrafts?.first)
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: draft, viewModel: model, field: .weight)
    let scrims = try WorkoutKeypadOverlay(session: keypad).inspect().findAll(ViewType.Button.self) {
      (try? $0.accessibilityIdentifier()) == "workout.keypad.dismiss"
    }
    #expect(scrims.isEmpty)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rpe)
    #expect(keypad.current?.field == .rpe)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rir)
    #expect(keypad.current?.field == .rir)
    keypad.openAllDay(draft: draft, viewModel: model, field: .weight)
    #expect(keypad.effortField(for: draft.id) == .rir)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rpe)
    #expect(keypad.effortField(for: draft.id) == .rpe)
  }

  @Test func restingRowHasDirectEffortEntry() throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    let draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    let button = try row.inspect().find(
      viewWithAccessibilityIdentifier: "allDay.effort.\(draft.id)"
    ).button()
    #expect(!button.isDisabled())
  }
}

@MainActor
@Test func effortComparisonOnlyShowsAConcreteDifferentPrescription() throws {
  struct Case {
    let target: PrescribedIntensity?
    let rpe: Decimal?
    let rir: Int?
    let original: String?
  }
  let cases: [Case] = [
    .init(target: nil, rpe: 9, rir: nil, original: nil),
    .init(target: .rpe(8), rpe: 8, rir: nil, original: nil),
    .init(target: .rpe(8), rpe: 9, rir: nil, original: "RPE 8"),
    .init(target: .rir(2), rpe: nil, rir: 2, original: nil),
    .init(target: .rir(2), rpe: nil, rir: 1, original: "RIR 2"),
    .init(target: .rpeRange(7, 8), rpe: 8, rir: nil, original: nil),
    .init(target: .rpeRange(7, 8), rpe: 9, rir: nil, original: "RPE 7–8"),
  ]
  for item in cases {
    let original = item.original
    var draft = try #require(
      AllDaySummaryTests.rows(AllDaySummaryTests.sets(1, intensity: item.target)).first)
    draft.actualRPE = item.rpe
    draft.actualRIR = item.rir
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    let originals = try row.inspect().findAll(ViewType.Text.self).filter {
      try $0.string().hasPrefix(StudentStrings.replacing(.allDayOriginal, values: [""]))
    }
    #expect(originals.count == (original == nil ? 0 : 1))
    if let original, let text = originals.first {
      #expect(try text.string() == StudentStrings.replacing(.allDayOriginal, values: [original]))
      #expect(try text.attributes().font() == .MeetPR.body(size: MeetPRFontMetrics.size10))
    }
  }
}

extension AllDayDirectEditingTests {
  @Test func warmupsCannotBecomeTopSetOrPreviousWeightSuggestions() {
    let exercise = UUID()
    var warmup = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: exercise, exerciseName: "Squat",
      isAccessory: false, liftFamily: .squat, planExerciseSortOrder: 1,
      prescribed: PrescribedSet(id: UUID(), setIndex: 3), actualWeight: 200,
      actualReps: 1, completed: true)
    warmup.isExtra = true
    warmup.isWarmup = true
    var target = TodayWorkoutSetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseID: exercise, exerciseName: "Squat",
      isAccessory: false, liftFamily: .squat, planExerciseSortOrder: 2,
      prescribed: PrescribedSet(
        id: UUID(), setIndex: 0, intensity: .percentage(85),
        percentageAnchor: .topSet, loadMode: .percentage, reps: 5))
    let topSet = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id, in: [warmup, target], currentE1RMKg: nil)
    #expect(topSet.suggestion == nil)
    #expect(topSet.unavailableReason == .topSetNotCompleted)
    target.prescribed = PrescribedSet(id: target.id, setIndex: 0, reps: 5, rpe: 8)
    let previous = TodayWorkoutViewModel.weightSuggestionOutcome(
      forSetID: target.id, in: [warmup, target], currentE1RMKg: nil, lastLoggedWeightKg: 100)
    #expect(previous.suggestion?.weightKg == 100)
  }

  @Test func legacyExtraSetNumberSurvivesADeletedSlotAndOldDraftDecodesWithoutWarmup() async throws
  {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = plan.days[0]
    let exercise = day.exercises[0]
    let log = StudentSetLog(
      id: UUID(), studentID: StudentDemoSeed.studentID, planExerciseID: exercise.id,
      setIndex: exercise.prescribedSets.count + 1, loggedAt: Date(),
      weightKg: 135, reps: 5, completed: true)
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository(seed: [log]))
    await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
    let draft = try #require(model.currentDrafts?.first { $0.loggedSetID == log.id })
    #expect(model.allDayDisplayNumber(for: draft) == log.setIndex + 1)
    var old = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
    old.removeValue(forKey: "warmup")
    old.removeValue(forKey: "allDayOriginalWeight")
    let decoded = try JSONDecoder().decode(
      TodayWorkoutSetRowDraft.self, from: JSONSerialization.data(withJSONObject: old))
    #expect(!decoded.isWarmup)
    #expect(decoded.isExtra)
    #expect(decoded.actualWeight == draft.actualWeight)
  }
}

extension AllDayDirectEditingTests {
  @Test func warmupRowHasNoCamera() throws {
    var draft = try #require(AllDaySummaryTests.rows(AllDaySummaryTests.sets(1)).first)
    draft.isExtra = true
    draft.isWarmup = true
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    let cameras = try row.inspect().findAll(ViewType.Button.self) {
      (try? $0.accessibilityIdentifier()) == "allDay.camera.\(draft.id)"
    }
    #expect(cameras.isEmpty)
  }
}
