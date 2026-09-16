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

// P0 2026-08-20: same schedule-clamped window as TodayWorkout — logs recorded
// after the plan's scheduled end must still reach the week overview.
@MainActor
@Test func weekOverviewKeepsLogsRecordedAfterScheduledPlanEnd() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let lastScheduled = try #require(plan.days.map(\.scheduledDate).max())
  let now = lastScheduled.addingTimeInterval(30 * 86_400)
  let day = plan.days[0]
  let exercise = try #require(day.exercises.first)
  let prescribed = try #require(exercise.prescribedSets.first)
  let lateLog = StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: exercise.id,
    setIndex: prescribed.setIndex,
    loggedAt: now.addingTimeInterval(-3_600),
    weightKg: 123.5,
    reps: 5,
    completed: true
  )
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(seed: [lateLog]),
    now: { now }
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(_, let fetchedLogs, _) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(fetchedLogs.contains { $0.id == lateLog.id })
}

// spec 080: same lower-bound guarantee as TodayWorkout — logs recorded on the
// original schedule before a coach shift must still reach the week overview.
@MainActor
@Test func weekOverviewKeepsLogsRecordedBeforeCoachShift() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = coachShiftedPlan(StudentDemoSeed.makePlanView(), byDays: 5)
  let store = TestStudentPlanStore(seed: [studentID: plan])
  let day = plan.days[0]
  let exercise = try #require(day.exercises.first)
  let prescribed = try #require(exercise.prescribedSets.first)
  let earlyLog = StudentSetLog(
    id: UUID(),
    studentID: studentID,
    planExerciseID: exercise.id,
    setIndex: prescribed.setIndex,
    loggedAt: day.scheduledDate.addingTimeInterval(3_600),
    weightKg: 100,
    reps: 5,
    completed: true
  )
  let viewModel = WeekOverviewViewModel(
    plans: InMemoryStudentPlanRepository(store: store),
    logs: InMemoryStudentTrainingLogRepository(seed: [earlyLog]),
    now: { day.date.addingTimeInterval(86_400) }
  )

  await viewModel.load(studentID: studentID)

  guard case .loaded(_, let fetchedLogs, _) = viewModel.state else {
    Issue.record("Expected loaded state")
    return
  }
  #expect(fetchedLogs.contains { $0.id == earlyLog.id })
}

private func coachShiftedPlan(_ seeded: StudentPlanView, byDays offset: Int) -> StudentPlanView {
  StudentPlanView(
    cycleID: seeded.cycleID,
    weekIndex: seeded.weekIndex,
    startDate: seeded.startDate,
    endDate: seeded.endDate,
    planKind: seeded.planKind,
    publishedAt: seeded.publishedAt,
    totalShiftDays: offset,
    days: seeded.days.map { day in
      StudentPlanDay(
        id: day.id,
        weekNumber: day.weekNumber,
        dayOfWeek: day.dayOfWeek,
        sortOrder: day.sortOrder,
        date: day.scheduledDate,
        shiftedToDate: day.scheduledDate.addingTimeInterval(Double(offset) * 86_400),
        completedAt: day.completedAt,
        completionSource: day.completionSource,
        exercises: day.exercises
      )
    }
  )
}
