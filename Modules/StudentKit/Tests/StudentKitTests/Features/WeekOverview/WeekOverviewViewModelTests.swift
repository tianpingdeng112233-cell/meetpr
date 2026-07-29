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

@MainActor
@Test func weekOverviewRetainsFullCycleForCrossWeekNextTrainingLookup() async throws {
  let studentID = StudentDemoSeed.studentID
  let seed = StudentDemoSeed.makePlanView()
  let nextWeekTraining = StudentPlanDay(
    id: UUID(),
    date: seed.days[6].date.addingTimeInterval(86_400),
    exercises: seed.days[0].exercises
  )
  let plan = StudentPlanView(
    cycleID: seed.cycleID,
    weekIndex: seed.weekIndex,
    startDate: seed.startDate,
    endDate: nextWeekTraining.date,
    planKind: seed.planKind,
    totalShiftDays: seed.totalShiftDays,
    latestShiftCreatedAt: seed.latestShiftCreatedAt,
    days: seed.days + [nextWeekTraining]
  )
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(let currentWeekDays, _, _) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(currentWeekDays.count == 7)
  #expect(viewModel.cycleDays.count == 8)
  #expect(viewModel.cycleDays.last?.id == nextWeekTraining.id)
}
