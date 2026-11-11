import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func allDayClearWeightThenNextFieldDoesNotRestoreOriginalValue() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
  let draft = try #require(model.currentDrafts?.first)
  let keypad = WorkoutKeypadSession()
  keypad.openAllDay(draft: draft, viewModel: model, field: .weight)
  keypad.update("")
  keypad.commit("")
  #expect(model.currentDrafts?.first?.actualWeight == nil)
}

@Test func allDayRecordedEmptyWeightRetainsActualEffortAndHighlightsRIRChange() {
  var rows = AllDaySummaryTests.rows(
    [6, 7, 8, 8].flatMap {
      AllDaySummaryTests.sets(1, reps: 12, intensity: .rpe(Decimal($0)))
    })
  for index in rows.indices { rows[index].loggedSetID = UUID() }
  let summary = AllDayExerciseSummary.build(rows: rows)
  #expect(summary.segments.map(\.effort) == ["RPE 6/7/8/8"])
  #expect(summary.segments[0].intensityOnly)
  rows = AllDaySummaryTests.rows(AllDaySummaryTests.sets(1, reps: 10, intensity: .rir(2)))
  rows[0].actualRIR = 3
  rows[0].loggedSetID = UUID()
  let changed = AllDayExerciseSummary.build(rows: rows)
  #expect(changed.segments.map(\.effort) == ["RIR 3"])
  #expect(changed.segments[0].effortChanged)
  #expect(!changed.segments[0].weightChanged)
  #expect(changed.segments[0].load == "—")
}

@MainActor
@Test(arguments: [false, true])
func allDayClearingCompletedWeightRemovesDerivedHistory(queued: Bool) async throws {
  let student = StudentDemoSeed.studentID
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let logs = InMemoryStudentTrainingLogRepository()
  let e1rm = InMemoryE1RMRepository()
  let queue =
    queued
    ? try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned(try await logs.recordSet($0.plannedLog))
    } : nil
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [student: plan])), logs: logs, e1rm: e1rm,
    setSyncQueue: queue,
    now: { day.date.addingTimeInterval(3600) })
  await model.load(dayID: day.id, studentID: student)
  model.updateWeight(rowIndex: 0, weight: 150)
  model.updateReps(rowIndex: 0, reps: 5)
  model.updateRPE(rowIndex: 0, rpe: 8)
  #expect(await model.saveAllDayRow(rowIndex: 0, completed: true))
  await queue?.drain()
  let row = try #require(model.currentDrafts?.first)
  #expect(try await e1rm.fetchHistory(studentId: student, exerciseId: row.exerciseID).count == 1)
  model.updateWeight(rowIndex: 0, weight: nil)
  #expect(await model.saveAllDayRow(rowIndex: 0))
  await queue?.drain()
  #expect(try await e1rm.fetchHistory(studentId: student, exerciseId: row.exerciseID).isEmpty)
  #expect(try await e1rm.fetchWeightBaselines(studentId: student).isEmpty)
  #expect(try await e1rm.prEvents(studentId: student, since: .distantPast).isEmpty)
}
