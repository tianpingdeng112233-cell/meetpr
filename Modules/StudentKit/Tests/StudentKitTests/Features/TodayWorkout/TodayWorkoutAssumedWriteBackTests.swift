import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func realSaveOverAssumedRecordRestoresSharingImmediately() async throws {
  // A real save overwrites an assumed record server-side (the fake mirrors the backend by
  // clearing `assumed` on upsert). The persist merge must write persisted.assumed back into
  // the draft, or the ask-coach entry stays hidden until a full reload.
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let firstSet = plan.days[0].exercises[0].prescribedSets[0]
  let assumedLog = StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: plan.days[0].exercises[0].id,
    exerciseID: plan.days[0].exercises[0].exercise.id,
    setIndex: firstSet.setIndex,
    loggedAt: plan.days[0].date.addingTimeInterval(10 * 3_600),
    weightKg: firstSet.weightKg ?? 100,
    reps: firstSet.reps ?? 5,
    rpe: nil,
    completed: true,
    failed: false,
    assumed: true
  )
  let logs = InMemoryStudentTrainingLogRepository(seed: [assumedLog])
  let viewModel = TodayWorkoutViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    logs: logs,
    now: { plan.days[0].date.addingTimeInterval(12 * 3_600) }
  )
  await viewModel.load(date: plan.days[0].date, studentID: studentID)

  guard case .loaded(_, let loaded) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(loaded[0].assumed)

  await viewModel.commitSet(rowIndex: 0)

  guard case .loaded(_, let merged) = viewModel.state else {
    Issue.record("Expected loaded state after commit")
    return
  }
  #expect(merged[0].completed)
  #expect(!merged[0].assumed)
}
