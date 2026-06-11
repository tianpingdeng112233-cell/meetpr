import Foundation
import Testing

@testable import StudentKit

@MainActor
@Test func weekOverviewViewModelLoadsDaysAndLogs() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let logs = InMemoryStudentTrainingLogRepository(
    seed: StudentDemoSeed.makeHistoricalLogs(studentID: studentID)
  )
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: logs
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(let days, let fetchedLogs, let weekIndex) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(days.count == 7)
  #expect(!fetchedLogs.isEmpty)
  #expect(weekIndex == plan.weekIndex)
}

@MainActor
@Test func weekOverviewViewModelHandlesEmptyPlan() async {
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore()),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: UUID())

  guard case .loaded(let days, let logs, _) = viewModel.state else {
    Issue.record("Expected loaded empty state")
    return
  }
  #expect(days.isEmpty)
  #expect(logs.isEmpty)
}
