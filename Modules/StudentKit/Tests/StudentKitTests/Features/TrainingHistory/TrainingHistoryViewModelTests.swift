import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func trainingHistoryViewModelLoadsEmptyHistory() async {
  let viewModel = TrainingHistoryViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .loaded(weeks: [], logs: []))
}

@MainActor
@Test func trainingHistoryViewModelRecoversWhenRetrySucceeds() async {
  let viewModel = TrainingHistoryViewModel(
    plans: RecoveringHistoryPlanRepository(),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)
  guard case .error = viewModel.state else {
    Issue.record("Expected the first request to surface a retryable error")
    return
  }

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .loaded(weeks: [], logs: []))
}

private actor RecoveringHistoryPlanRepository: StudentPlanRepository {
  private var hasFailed = false

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    if !hasFailed {
      hasFailed = true
      throw URLError(.timedOut)
    }
    return nil
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
}

@MainActor
@Test func trainingHistoryViewModelIgnoresURLCancellation() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { URLError(.cancelled) },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .idle)
}

@MainActor
@Test func trainingHistoryViewModelIgnoresCancellationError() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { CancellationError() },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  #expect(viewModel.state == .idle)
}

@MainActor
@Test func trainingHistoryViewModelSurfacesRealError() async {
  let viewModel = TrainingHistoryViewModel(
    plans: ThrowingStudentPlanRepository { URLError(.timedOut) },
    logs: FailingTrainingLogRepository()
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  guard case .error = viewModel.state else {
    Issue.record("Expected a non-cancellation error to surface as .error")
    return
  }
}

@MainActor
@Test func trainingHistoryViewModelGroupsCycleDaysIntoWeeks() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let viewModel = TrainingHistoryViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
    )
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(let weeks, let logs) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(weeks.count == 2)
  #expect(weeks.flatMap(\.days).count == 8)
  #expect(!logs.isEmpty)
}

@MainActor
@Test(arguments: [2, 9, 18])
func trainingHistoryIncludesTodaysQuickLogBeforeNoon(hour: Int) async throws {
  let calendar = WorkoutDatePolicy.deviceCalendar
  let now = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: hour)))
  let noon = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12)))
  let studentID = StudentDemoSeed.studentID
  let repository = InMemoryStudentTrainingLogRepository()
  let saved = try await repository.recordSet(
    StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: UUID(), setIndex: 0,
      loggedAt: noon, loggedDate: "2026-09-16", weightKg: 175, reps: 3, rpe: 8.5,
      completed: true
    )
  )
  let evening = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 17)))
  let tomorrow = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 12)))
  let ordinary = try await repository.recordSet(
    StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: UUID(), setIndex: 0,
      loggedAt: evening, weightKg: 180, reps: 3, completed: true
    )
  )
  try await repository.recordSet(
    StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: UUID(), setIndex: 0,
      loggedAt: tomorrow, loggedDate: "2026-09-17", weightKg: 180, reps: 3, completed: true
    )
  )
  let viewModel = TrainingHistoryViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: repository, now: { now }
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(_, let logs) = viewModel.state else {
    Issue.record("Expected saved quick-log records in history")
    return
  }
  #expect(logs.map(\.id) == (hour == 18 ? [saved.id, ordinary.id] : [saved.id]))
}
