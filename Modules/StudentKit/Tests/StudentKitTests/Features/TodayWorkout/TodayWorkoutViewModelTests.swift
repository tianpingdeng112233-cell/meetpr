import Foundation
import Testing

@testable import StudentKit

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
