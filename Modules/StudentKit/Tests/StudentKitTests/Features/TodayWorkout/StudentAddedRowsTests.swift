import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func plannedBaselinesKeepCompetitionStanceWhileAddedRecordsUseTheirFamily() {
  let exercise = Exercise(
    id: UUID(), name: "Sumo", exerciseType: .mainLift, mainLiftFamily: .deadlift,
    isCompetitionLift: true, competitionStance: .sumo, muscleGroups: [], equipment: [],
    createdAt: Date())
  let student = UUID()
  let profile = OnboardingProfile(
    userId: student, deadliftStyle: .conventional, createdAt: Date(), updatedAt: Date())
  let planned = StudentSetLog(
    id: UUID(), studentID: student, planExerciseID: UUID(), exerciseID: exercise.id,
    setIndex: 0, loggedAt: Date(), weightKg: 200, reps: 1, completed: true)
  let added = StudentAddedSetLog(
    id: UUID(), studentID: student, planDayID: UUID(), exerciseID: exercise.id,
    setIndex: 0, loggedAt: Date(), weightKg: 180, reps: 1, completed: true)
  let baselines = StudentAddedDerivedHistory.baselines(
    StudentWorkoutLogs(planned: [planned], added: [added]), days: [], catalog: [exercise],
    profile: profile)
  #expect(baselines.map(\.setLogId) == [added.id])
  #expect(baselines.first?.maxWeightKg == 180)
}

@MainActor
@Test func extraRowsNeverReplacePrescriptionProgressAndBatch() throws {
  let plan = StudentDemoSeed.makePlanView()
  let day = try #require(plan.days.first)
  let exercise = try #require(day.exercises.first)
  let extra = StudentSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planExerciseID: exercise.id,
    setIndex: exercise.prescribedSets.count, loggedAt: Date(), weightKg: 120, reps: 3,
    completed: true)
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [extra])
  let extraDraft = try #require(drafts.first { $0.loggedSetID == extra.id })
  #expect(extraDraft.isExtra)
  #expect(
    TodayWorkoutProgress(day: day, drafts: drafts).remainingSets
      == day.exercises.reduce(0) { $0 + $1.prescribedSets.count })
  let pending = try #require(StudentAddedRows.extra(exercise: exercise, drafts: drafts))
  #expect(pending.actualWeight == 120)
  #expect(pending.actualReps == 3)
  #expect(pending.actualRPE == nil)
  #expect(
    AccessoryRow.selection([AccessoryRow(draft: pending, previous: nil, unit: .kg)]).writable
      .isEmpty)
}

@MainActor
@Test func quickLogKeepsExtraRowsReadOnlyAndEnforcesTenExtraLimit() throws {
  let plan = StudentDemoSeed.makePlanView()
  let day = try #require(plan.days.first)
  let exercise = try #require(day.exercises.first)
  var drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  for _ in 0..<10 {
    drafts.append(try #require(StudentAddedRows.extra(exercise: exercise, drafts: drafts)))
  }
  #expect(StudentAddedRows.extra(exercise: exercise, drafts: drafts) == nil)
  var quick = QuickLogPlan(
    drafts: drafts, selectedDate: Date(),
    allowedDateRange: Date.distantPast...Date.distantFuture, calendar: .current)
  let extra = try #require(drafts.last)
  quick.setIncluded(true, for: extra.id)
  #expect(quick.rows.count == drafts.count)
  #expect(quick.rows.last?.included == false)
  #expect(quick.entries(studentID: StudentDemoSeed.studentID).count == drafts.count - 10)
}

@Test func addedHistoryMarksExtraAndIncludesFamilyRecords() throws {
  let plan = StudentDemoSeed.makePlanView()
  let exercise = try #require(plan.days.first?.exercises.first)
  let log = StudentAddedSetLog(
    id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: plan.days.first?.id,
    exerciseID: exercise.exercise.id, setIndex: 0, loggedAt: Date(), weightKg: 100,
    reps: 5, rpe: 8, completed: true)
  #expect(
    StudentAddedHistory.family(log, catalog: [exercise.exercise])
      == exercise.exercise.mainLiftFamily)
  #expect(
    StudentAddedHistory.extraIndices(
      exercise: exercise,
      logs: [
        StudentSetLog(
          id: UUID(), studentID: log.studentID, planExerciseID: exercise.id,
          setIndex: exercise.prescribedSets.count, loggedAt: Date(), weightKg: 100, reps: 5,
          completed: true)
      ]) == [exercise.prescribedSets.count])
}

@MainActor
@Test func extraPrefillUsesMostRecentlyRecordedSet() throws {
  let day = try #require(StudentDemoSeed.makePlanView().days.first)
  let exercise = try #require(day.exercises.first)
  let now = Date()
  let records = [
    StudentSetLog(
      id: UUID(), studentID: StudentDemoSeed.studentID,
      planExerciseID: exercise.id, setIndex: 0, loggedAt: now, weightKg: 90, reps: 4,
      completed: true),
    StudentSetLog(
      id: UUID(), studentID: StudentDemoSeed.studentID,
      planExerciseID: exercise.id, setIndex: 1, loggedAt: now.addingTimeInterval(-60),
      weightKg: 80, reps: 5, completed: true),
  ]
  let drafts = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: records)
  let row = try #require(StudentAddedRows.extra(exercise: exercise, drafts: drafts))
  #expect(row.actualWeight == 90)
  #expect(row.actualReps == 4)
}

@Test func addedRecordsContributeToHistoryStatsAndCSV() {
  let record = StudentAddedSetLog(
    id: UUID(), studentID: UUID(), planDayID: UUID(), exerciseID: UUID(), setIndex: 0,
    loggedAt: Date(), weightKg: 50, reps: 5, completed: true)
  let stats = GrowthScreenPresentation.historyStats(logs: [], added: [record])
  #expect(stats.totalVolumeKg == 250)
  #expect(stats.trainingSessionCount == 1)
  let csv = TrainingLogCSVExporter.csv(logs: [], names: [:], added: [record], catalog: [])
  #expect(csv.split(separator: "\n").count == 2)
  #expect(csv.hasSuffix(",true"))
}

@MainActor
@Test func previousAddedSessionUsesMatchingIndexAndIgnoresFailed() throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let exercise = plan.days[0].exercises[0]
  let now = Date()
  let logs =
    (0..<2).map { index in
      StudentAddedSetLog(
        id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: UUID(),
        exerciseID: exercise.exercise.id, setIndex: index,
        loggedAt: now.addingTimeInterval(-86_400 + Double(index)),
        weightKg: Decimal(50 + index * 10), reps: 5, completed: true)
    } + [
      StudentAddedSetLog(
        id: UUID(), studentID: StudentDemoSeed.studentID, planDayID: UUID(),
        exerciseID: exercise.exercise.id, setIndex: 0, loggedAt: now, weightKg: 120, reps: 1,
        completed: true, failed: true)
    ]
  var draft = TodayWorkoutViewModel.makeDrafts(for: plan.days[0], existingLogs: [])[0]
  draft.studentAddedDayID = plan.days[0].id
  let result = StudentAddedPreviousSession.find(
    draft: draft,
    records: StudentWorkoutLogs(planned: [], added: logs), days: plan.days, calendar: .current)
  #expect(result.added?.weightKg == 50)
  #expect(result.added?.setIndex == 0)
}

@MainActor
@Test func restoredAccessoryExtraKeepsActualRIRWhenWeightChanges() throws {
  let exercise = Exercise(
    id: UUID(), name: "Row", exerciseType: .accessory, isCompetitionLift: false, muscleGroups: [],
    equipment: [], createdAt: Date())
  let prescribed = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, reps: 10)])
  let log = StudentSetLog(
    id: UUID(), studentID: UUID(), planExerciseID: prescribed.id, setIndex: 1, loggedAt: Date(),
    weightKg: 20, reps: 10, actualRIR: 2, completed: true)
  let draft = try #require(StudentAddedRows.restoredExtras(exercise: prescribed, logs: [log]).first)
  var row = AccessoryRow(draft: draft, previous: nil, unit: .kg)
  row.input.weight = "25"
  #expect(row.rir == 2 && row.rpe == nil && row.weightKg == 25)
  row.switchEffort(to: .rpe)
  #expect(row.rir == 2)
}
