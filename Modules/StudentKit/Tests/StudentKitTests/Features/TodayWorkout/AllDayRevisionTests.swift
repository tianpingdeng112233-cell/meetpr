import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func allDayStartsCollapsedAndCompletingAnExerciseExpandsTheNext() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let original = plan.days[0]
  let exercise = try #require(original.exercises.first)
  let secondSlot = StudentPlanExercise(
    id: UUID(), exercise: exercise.exercise, sequenceIndex: 1,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, weightKg: 50, reps: 5)])
  let day = StudentPlanDay(
    id: original.id, date: original.date,
    exercises: [exercise, secondSlot])
  let twoExercisePlan = StudentPlanView(
    cycleID: plan.cycleID, weekIndex: 1,
    startDate: day.date, days: [day])
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: twoExercisePlan])),
    logs: InMemoryStudentTrainingLogRepository())
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  let first = try #require(model.allDaySheet.first?.id)
  let second = try #require(model.allDaySheet.dropFirst().first?.id)
  #expect(model.expandedAllDayExerciseID == nil)
  #expect(model.allDaySheet.first?.node == .current)
  model.toggleAllDayExpansion(first)
  #expect(model.expandedAllDayExerciseID == first)
  model.toggleAllDayExpansion(second)
  #expect(model.expandedAllDayExerciseID == second)
  model.toggleAllDayExpansion(second)
  #expect(model.expandedAllDayExerciseID == nil)
  model.toggleAllDayExpansion(first)
  #expect(await model.toggleAllDayExercise(first))
  #expect(model.expandedAllDayExerciseID == second)
  #expect(model.allDaySheet[1].node == .current)
  #expect(await model.toggleAllDayExercise(second))
  #expect(model.expandedAllDayExerciseID == nil)
  model.toggleAllDayExpansion(first)
  #expect(model.expandedAllDayExerciseID == first)
  #expect(model.allDaySheet.first?.node == .completed)
  #expect(await model.toggleAllDayExercise(first))
  #expect(model.expandedAllDayExerciseID == first)
}

@MainActor
@Test func allDayTopSetPercentagePrefillsAfterCompletionAndSavesDisplayedWeight() async throws {
  let original = StudentAddedTestPlan.unsettledDemo().days[0]
  let exercise = try #require(original.exercises.first?.exercise)
  let top = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, weightKg: 150, reps: 1)])
  let backoff = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 1,
    prescribedSets: [
      PrescribedSet(
        id: UUID(), setIndex: 0, intensity: .percentage(60),
        percentageAnchor: .topSet, loadMode: .percentage, reps: 5)
    ])
  let day = StudentPlanDay(id: UUID(), date: original.date, exercises: [top, backoff])
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: day.date, days: [day])
  let logs = InMemoryStudentTrainingLogRepository()
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])), logs: logs)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  #expect(model.currentDrafts?[1].actualWeight == nil)
  #expect(await model.toggleAllDayExercise(top.id))
  #expect(model.currentDrafts?[1].actualWeight == 90)
  model.updateWeight(rowIndex: 0, weight: 160)
  #expect(await model.saveAllDayRow(rowIndex: 0))
  #expect(model.currentDrafts?[1].actualWeight == 95)
  #expect(await model.completeCurrentDay())
  #expect(
    try await logs.fetchLogsForExercise(
      studentID: StudentDemoSeed.studentID,
      planExerciseID: backoff.id
    ).first?.weightKg == 95)
}

@MainActor
@Test func allDayCompletionSkipsBlankExtraAndAllowsAnEmptyDay() async throws {
  let original = StudentAddedTestPlan.unsettledDemo().days[0]
  let exercise = try #require(original.exercises.first?.exercise)
  let slot = StudentPlanExercise(
    id: UUID(), exercise: exercise, sequenceIndex: 0,
    prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0)])
  for exercises in [[slot], []] {
    let day = StudentPlanDay(id: UUID(), date: original.date, exercises: exercises)
    let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: day.date, days: [day])
    let logs = InMemoryStudentTrainingLogRepository()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])), logs: logs)
    await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
    if !exercises.isEmpty { model.addExtraSet(exerciseID: slot.id) }
    #expect(model.completionWrites.count == exercises.count)
    #expect(await model.completeCurrentDay())
    #expect(model.completionPhase == .celebration)
    let saved = try await logs.fetchAllLogs(
      studentID: StudentDemoSeed.studentID,
      in: Date.distantPast...Date.distantFuture)
    #expect(saved.planned.count == exercises.count)
    #expect(saved.added.isEmpty)
  }
}

@MainActor
@Test func allDayLoadedCompletedExerciseStaysCollapsedUntilExplicitlyReopened() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let first = try #require(day.exercises.first)
  let logs = InMemoryStudentTrainingLogRepository()
  for set in first.prescribedSets {
    _ = try await logs.recordSet(
      StudentSetLog(
        id: UUID(), studentID: StudentDemoSeed.studentID,
        planExerciseID: first.id, setIndex: set.setIndex, loggedAt: day.date,
        weightKg: 90, reps: 4, completed: true))
  }
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])), logs: logs)
  await model.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
  #expect(model.allDaySheet.first?.node == .completed)
  #expect(model.expandedAllDayExerciseID == nil)
  #expect(await model.toggleAllDayExercise(first.id))
  #expect(model.allDaySheet.first?.node == .current)
  #expect(model.expandedAllDayExerciseID == first.id)
  #expect(model.currentDrafts?.first?.actualWeight == 90)
}

@MainActor
@Test func allDayPoundEditingStoresMetricAndAllowsClearingWeight() async throws {
  let plan = StudentAddedTestPlan.unsettledDemo()
  let day = plan.days[0]
  let student = StudentDemoSeed.studentID
  let profile = OnboardingProfile(
    userId: student, unitPreference: .lb,
    createdAt: day.date, updatedAt: day.date)
  let model = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [student: plan])),
    logs: InMemoryStudentTrainingLogRepository(),
    onboarding: InMemoryOnboardingRepository(studentId: student, seed: profile))
  await model.load(dayID: day.id, studentID: student)
  let row = try #require(model.currentDrafts?.first)
  let keypad = WorkoutKeypadSession()
  keypad.openAllDay(draft: row, viewModel: model, field: .weight)
  keypad.update("220.5")
  keypad.dismiss()
  #expect(model.currentDrafts?.first?.actualWeight == 100.02)
  let edited = try #require(model.currentDrafts?.first)
  keypad.openAllDay(draft: edited, viewModel: model, field: .weight)
  keypad.update("")
  keypad.dismiss()
  #expect(model.currentDrafts?.first?.actualWeight == nil)
}

@MainActor
@Test func allDayEffortChoiceSurvivesReloadAndIsolatesAccountsAndExercises() async throws {
  let suite = "effort-test-" + UUID().uuidString
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let student = UUID()
  let otherStudent = UUID()
  let plan = StudentAddedTestPlan.unsettledDemo()
  let repository = InMemoryStudentPlanRepository(
    store: TestStudentPlanStore(seed: [student: plan, otherStudent: plan]))
  let model = TodayWorkoutViewModel(
    plans: repository, logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await model.load(dayID: plan.days[0].id, studentID: student)
  let row = try #require(AllDaySummaryTests.rows(AllDaySummaryTests.sets(1, weight: 100)).first)
  #expect(model.previousAllDayEffort(for: row) == nil)
  model.rememberAllDayEffort(.rir, for: row)
  let restored = TodayWorkoutViewModel(
    plans: repository, logs: InMemoryStudentTrainingLogRepository(), effortDefaults: defaults)
  await restored.load(dayID: plan.days[0].id, studentID: student)
  #expect(restored.previousAllDayEffort(for: row) == .rir)
  #expect(row.allDayEffortMode(previous: restored.previousAllDayEffort(for: row)) == .rir)
  let otherRow = try #require(
    AllDaySummaryTests.rows(AllDaySummaryTests.sets(1, weight: 100)).first)
  #expect(restored.previousAllDayEffort(for: otherRow) == nil)
  await restored.load(dayID: plan.days[0].id, studentID: otherStudent)
  #expect(restored.previousAllDayEffort(for: row) == nil)
  await restored.load(dayID: plan.days[0].id, studentID: student)
  #expect(restored.previousAllDayEffort(for: row) == .rir)
}
