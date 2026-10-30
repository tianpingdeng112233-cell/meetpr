import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func loadTypeBodyweightAcceptsEmptyAndPreservesExtraWeight() throws {
  var row = loadTypeRow(mode: .bodyweight)
  #expect(row.isBodyweight)
  #expect(row.input.weight == "0")
  #expect(!row.draft.completed)
  row.input.weight = ""
  #expect(row.isWritable)
  #expect(row.weightKg == 0)
  row.input.weight = "12.5"
  #expect(row.isWritable && row.weightKg == 12.5)
  row.input.weight = "invalid"
  #expect(!row.isWritable)
}

@MainActor
@Test func loadTypeFreeWeightOverridesLegacyMarkerAndRequiresActualWeight() {
  var row = loadTypeRow(mode: .freeWeight, note: "自重")
  #expect(!row.isBodyweight)
  #expect(!row.isWritable)
  row.input.weight = "25"
  #expect(row.isWritable && row.weightKg == 25)
}

@MainActor
@Test func loadTypeLegacyBodyweightRetainsOtherCoachCuesAndExtraWeight() {
  var row = loadTypeRow(mode: nil, note: "自重 · 慢下放", rpe: 10)
  #expect(row.isBodyweight && row.isWritable)
  #expect(row.extraNote == "慢下放")
  row.input.weight = "10"
  #expect(row.weightKg == 10)
}

@MainActor
private func loadTypeRow(mode: PlanLoadMode?, note: String? = nil, rpe: Decimal = 8) -> AccessoryRow
{
  let exercise = Exercise(
    id: UUID(), name: "Row", exerciseType: .accessory, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: .distantPast)
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [
      PrescribedSet(
        id: UUID(), setIndex: 0, intensity: .rpe(rpe), loadMode: mode, reps: 15,
        coachNote: note)
    ])
  let draft = TodayWorkoutViewModel.makeDraft(
    exercise: planExercise, set: planExercise.prescribedSets[0], existingLogs: [])
  return AccessoryRow(draft: draft, previous: nil, unit: .kg)
}

@MainActor
@Test func loadTypeCompletionCannotPersistMissingFreeWeight() async throws {
  let fixture = await loadTypeFixture(mode: .freeWeight)
  #expect(!(await fixture.model.commitSet(rowIndex: 0)))
  #expect(fixture.model.currentDrafts?.first?.completed == false)
  #expect(fixture.model.actionErrorMessage != nil)
  #expect(
    try await fixture.logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: fixture.exerciseID
    ).isEmpty)
  fixture.model.updateWeight(rowIndex: 0, weight: 25)
  #expect(await fixture.model.commitSet(rowIndex: 0))
  #expect(fixture.model.currentDrafts?.first?.actualWeight == 25)
}

@MainActor
@Test func loadTypeQuickLogCannotBypassRequiredWeight() async throws {
  let fixture = await loadTypeFixture(mode: .freeWeight)
  let plan = try #require(fixture.model.makeQuickLogPlan())
  #expect(
    await fixture.model.quickLog(plan: plan) == .partialFailure(writtenCount: 0, failedIndex: 0))
  #expect(
    try await fixture.logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: fixture.exerciseID
    ).isEmpty)
}

@MainActor
@Test func loadTypeBodyweightSaveReloadAndOverwritePreserveWeight() async throws {
  let fixture = await loadTypeFixture(mode: .bodyweight)
  var row = AccessoryRow(
    draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
  #expect(await fixture.model.saveAccessoryRow(row))
  await fixture.model.load(dayID: fixture.dayID, studentID: StudentDemoSeed.studentID)
  row = AccessoryRow(
    draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
  #expect(row.draft.completed && row.weightKg == 0)
  row.input.weight = "12.5"
  #expect(await fixture.model.saveAccessoryRow(row))
  let saved = try #require(
    try await fixture.logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID, planExerciseID: fixture.exerciseID
    ).first)
  #expect(saved.weightKg == 12.5 && saved.completed)
}

@MainActor
@Test func loadTypeMainLiftUsesSameExplicitWeightRecording() async throws {
  let fixture = await loadTypeFixture(mode: .freeWeight, exerciseType: .mainLift)
  var row = AccessoryRow(
    draft: try #require(fixture.model.currentDrafts?.first), previous: nil, unit: .kg)
  row.input.weight = "20"
  #expect(await fixture.model.saveAccessoryRow(row))
  #expect(fixture.model.currentDrafts?.first?.completed == true)
}

@MainActor
private func loadTypeFixture(mode: PlanLoadMode, exerciseType: ExerciseType = .accessory) async
  -> LoadTypeFixture
{
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Row", exerciseType: exerciseType, isCompetitionLift: false,
    muscleGroups: [], equipment: [], createdAt: now)
  let planExercise = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, loadMode: mode, reps: 15)])
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [planExercise])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: [day])
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
    logs: logs, now: { now })
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  return LoadTypeFixture(model: model, logs: logs, exerciseID: planExercise.id, dayID: day.id)
}

private struct LoadTypeFixture {
  let model: TodayWorkoutViewModel
  let logs: InMemoryStudentTrainingLogRepository
  let exerciseID: UUID
  let dayID: UUID
}
