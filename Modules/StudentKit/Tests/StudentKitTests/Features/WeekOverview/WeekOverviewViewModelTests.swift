import CoreModels
import Foundation
import RepositoryContracts
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
  #expect(days.count == 4)
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
    weekNumber: 3,
    dayOfWeek: 1,
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
  #expect(currentWeekDays.count == 4)
  #expect(viewModel.cycleDays.count == 9)
  #expect(viewModel.cycleDays.last?.id == nextWeekTraining.id)
}

@MainActor
@Test func initialLoadUsesNewlyPublishedPlanInOnePass() async throws {
  let studentID = UUID()
  let cached = StudentDemoSeed.makePlanView()
  let published = StudentPlanView(
    cycleID: UUID(),
    weekIndex: cached.weekIndex,
    startDate: cached.startDate,
    endDate: cached.endDate,
    planKind: cached.planKind,
    publishedAt: cached.publishedAt?.addingTimeInterval(1) ?? Date(),
    days: cached.days
  )
  let plans = AuthoritativePlanRepository(cached: cached, refreshed: published)
  let viewModel = WeekOverviewViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: studentID)
  #expect(viewModel.plan?.cycleID == published.cycleID)
  #expect(await plans.refreshCount == 1)
  #expect(await plans.fetchCount == 0)
}

@MainActor
@Test func initialLoadFallsBackToCachedPlanWhenRefreshFails() async {
  let cached = StudentDemoSeed.makePlanView()
  let plans = AuthoritativePlanRepository(
    cached: cached,
    refreshed: cached,
    refreshError: TestError()
  )
  let viewModel = WeekOverviewViewModel(
    plans: plans,
    logs: InMemoryStudentTrainingLogRepository()
  )

  await viewModel.load(studentID: UUID())

  #expect(viewModel.plan?.cycleID == cached.cycleID)
  #expect(await plans.refreshCount == 1)
  #expect(await plans.fetchCount == 1)
}

private actor AuthoritativePlanRepository: StudentPlanRepository {
  let cached: StudentPlanView
  let refreshed: StudentPlanView
  let refreshError: (any Error)?
  private(set) var fetchCount = 0
  private(set) var refreshCount = 0

  init(
    cached: StudentPlanView,
    refreshed: StudentPlanView,
    refreshError: (any Error)? = nil
  ) {
    self.cached = cached
    self.refreshed = refreshed
    self.refreshError = refreshError
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    fetchCount += 1
    return cached
  }

  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    refreshCount += 1
    if let refreshError { throw refreshError }
    return refreshed
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    refreshed.days
  }
}
