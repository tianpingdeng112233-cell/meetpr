import CoreModels
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
  #expect(viewModel.algorithmMetadata?.isEmpty == true)
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
  #expect(viewModel.algorithmMetadata == nil)
}

@MainActor
@Test func weekOverviewViewModelExposesAlgorithmMetadata() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: Date(timeIntervalSince1970: 1_783_036_800),
    blockType: "strength",
    mesocyclePhase: "intensification",
    trainingMax: Decimal(92.5),
    tmSetAt: Date(timeIntervalSince1970: 1_783_036_800),
    days: []
  )
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: studentID)

  let badges = try #require(viewModel.algorithmMetadata?.badges(now: plan.startDate))
  #expect(badges.map(\.title) == ["力量块", "强化", "训练最大值 ≈ 0.9×1RM 92.5kg"])
}
