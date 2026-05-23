import CoreModels
import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func studentSessionSummaryAggregatesCompletedSetsOnly() {
  let prescribed = PrescribedSet(
    id: UUID(), setIndex: 0, weightKg: 100, reps: 5, repsMax: nil, rpe: 8)
  func draft(
    weight: Decimal, reps: Int, rpe: Decimal, completed: Bool
  ) -> TodayWorkoutViewModel.SetRowDraft {
    TodayWorkoutViewModel.SetRowDraft(
      id: UUID(), planExerciseID: UUID(), exerciseName: "深蹲",
      prescribed: prescribed, actualWeight: weight, actualReps: reps,
      actualRPE: rpe, completed: completed)
  }

  let summary = StudentSessionSummary(drafts: [
    draft(weight: 100, reps: 5, rpe: 8, completed: true),
    draft(weight: 120, reps: 3, rpe: 9, completed: true),
    draft(weight: 100, reps: 5, rpe: 7, completed: false),
  ])

  #expect(summary.completedSets == 2)
  #expect(summary.totalReps == 8)
  #expect(summary.totalVolumeKg == 860)  // 100*5 + 120*3
  #expect(summary.averageRPE == 8.5)  // (8 + 9) / 2
}

@Test func studentFormattingResultOmitsMissingWeightAndRPE() {
  #expect(StudentFormatting.result(weightKg: 142.5, reps: 5, rpe: 7.5) == "142.5kg × 5 @ RPE 7.5")
  #expect(StudentFormatting.result(weightKg: nil, reps: 5, rpe: 8) == "5 @ RPE 8")
  #expect(StudentFormatting.result(weightKg: 100, reps: 5, rpe: nil) == "100kg × 5")
}

@MainActor
@Test func studentSessionSummaryReportsTopSetPerExercise() {
  let squatID = UUID()
  func draft(
    setIndex: Int, weight: Decimal, reps: Int, rpe: Decimal, completed: Bool
  ) -> TodayWorkoutViewModel.SetRowDraft {
    TodayWorkoutViewModel.SetRowDraft(
      id: UUID(), planExerciseID: squatID, exerciseName: "深蹲",
      prescribed: PrescribedSet(
        id: UUID(), setIndex: setIndex, weightKg: weight, reps: reps, repsMax: nil, rpe: rpe),
      actualWeight: weight, actualReps: reps, actualRPE: rpe, completed: completed)
  }

  let summary = StudentSessionSummary(drafts: [
    draft(setIndex: 0, weight: 100, reps: 5, rpe: 7, completed: true),
    draft(setIndex: 1, weight: 142.5, reps: 5, rpe: 8, completed: true),  // top set
    draft(setIndex: 2, weight: 150, reps: 5, rpe: 9, completed: false),  // heavier but not done
  ])

  #expect(summary.exercises.count == 1)
  let squat = summary.exercises.first
  #expect(squat?.name == "深蹲")
  #expect(squat?.topSetWeightKg == 142.5)
  #expect(squat?.topSetReps == 5)
  #expect(squat?.topSetRPE == 8)
}

@Test func makeHistoricalLogsSeedsNoFutureLogs() {
  let startOfTomorrow = Calendar(identifier: .gregorian)
    .startOfDay(for: Date())
    .addingTimeInterval(86_400)
  let logs = StudentDemoSeed.makeHistoricalLogs()
  #expect(!logs.isEmpty)
  #expect(logs.allSatisfy { $0.loggedAt < startOfTomorrow })
}

@MainActor
@Test func todayWorkoutViewModelPersistsEditsToCompletedSet() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  // Complete the set, then edit the already-completed set and re-save.
  await viewModel.commitSet(rowIndex: 0)
  viewModel.updateReps(rowIndex: 0, reps: 7)
  await viewModel.commitSet(rowIndex: 0)

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  guard case .loaded(_, let reloaded) = viewModel.state else {
    Issue.record("Expected loaded state after reload")
    return
  }
  #expect(reloaded[0].completed)
  #expect(reloaded[0].actualReps == 7)
}

@MainActor
@Test func todayWorkoutViewModelLoadsRecordsAndReturnsToLoaded() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )

  #expect(viewModel.state == .idle)
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  guard case .loaded(let day, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(day == plan.days[0])
  #expect(drafts.count == 3)

  viewModel.updateReps(rowIndex: 0, reps: 4)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded(_, let recordedDrafts) = viewModel.state else {
    Issue.record("Expected loaded state after recording")
    return
  }
  #expect(recordedDrafts[0].completed)

  let recordedLogs = try await logs.fetchLogsForExercise(
    studentID: studentID,
    planExerciseID: recordedDrafts[0].planExerciseID
  )
  #expect(recordedLogs.count == 1)
  #expect(recordedLogs[0].reps == 4)

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  guard case .loaded(_, let reloadedDrafts) = viewModel.state else {
    Issue.record("Expected loaded state after reload")
    return
  }
  #expect(reloadedDrafts[0].completed)
  #expect(reloadedDrafts[0].actualReps == 4)
}

@MainActor
@Test func todayWorkoutViewModelUpdatesActualWeight() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository()
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(3_600) }
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  viewModel.updateWeight(rowIndex: 0, weight: 142.5)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .loaded(_, let drafts) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(drafts[0].actualWeight == 142.5)

  let recordedLogs = try await logs.fetchLogsForExercise(
    studentID: studentID,
    planExerciseID: drafts[0].planExerciseID
  )
  #expect(recordedLogs[0].weightKg == 142.5)
}

@MainActor
@Test func todayWorkoutViewModelMovesToErrorWhenRecordingFails() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(date: plan.days[0].date, studentID: studentID)
  await viewModel.toggleComplete(rowIndex: 0)

  guard case .error = viewModel.state else {
    Issue.record("Expected error state")
    return
  }
}
