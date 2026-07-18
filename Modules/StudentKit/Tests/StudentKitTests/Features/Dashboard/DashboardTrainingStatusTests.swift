import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func dashboardTrainingStatusRendersNotStartedInProgressAndCompletedStates() async {
  let start = Date(timeIntervalSince1970: 1_768_732_800)
  let day = dashboardPlanDay(date: start)

  let notStarted = DashboardTrainingStatusViewModel(
    sessions: DashboardSessionRepository(session: nil),
    now: { start },
    onOpenTraining: {}
  )
  await notStarted.reload()
  #expect(
    notStarted.status(for: day)
      == .notStarted(dayName: "BD 日", setCount: 9))
  #expect(notStarted.status(for: day).accessibilityText == "今日 · BD 日 · 9 组 › 开始训练")

  let inProgressSession = TrainingSession(
    status: .inProgress,
    startedAt: start.addingTimeInterval(-2_892),
    lastSetAt: start,
    completedAt: nil,
    durationSeconds: 0
  )
  let inProgress = DashboardTrainingStatusViewModel(
    sessions: DashboardSessionRepository(session: inProgressSession),
    now: { start },
    onOpenTraining: {}
  )
  await inProgress.reload()
  #expect(inProgress.status(for: day) == .inProgress(elapsedSeconds: 2_892))
  #expect(inProgress.status(for: day).accessibilityText == "训练中 · 48:12")

  let completedSession = TrainingSession(
    status: .completed,
    startedAt: start.addingTimeInterval(-3_480),
    lastSetAt: start,
    completedAt: start,
    durationSeconds: 3_480
  )
  let completed = DashboardTrainingStatusViewModel(
    sessions: DashboardSessionRepository(session: completedSession),
    now: { start },
    onOpenTraining: {}
  )
  await completed.reload()
  #expect(completed.status(for: day) == .completed(durationMinutes: 58))
  #expect(completed.status(for: day).accessibilityText == "今日已完成 · 58 分钟")
}

@MainActor
@Test func dashboardPartialStatusIsDistinctFromCompleted() async {
  let now = Date(timeIntervalSince1970: 1_768_732_800)
  let partialSession = TrainingSession(
    status: .partial,
    startedAt: now.addingTimeInterval(-1_500),
    lastSetAt: now,
    completedAt: now,
    durationSeconds: 1_500
  )
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: DashboardSessionRepository(session: partialSession),
    now: { now },
    onOpenTraining: {}
  )

  await viewModel.reload()

  #expect(viewModel.status(for: dashboardPlanDay(date: now)) == .partial(durationMinutes: 25))
  #expect(viewModel.status(for: dashboardPlanDay(date: now)).accessibilityText == "今日已练 · 25 分钟")
}

@MainActor
@Test func serverGymDayKeepsCrossoverCompletionAuthoritative() async {
  let localToday = Date(timeIntervalSince1970: 1_768_732_800)
  let completed = TrainingSession(
    status: .completed,
    startedAt: localToday.addingTimeInterval(-3_600),
    lastSetAt: localToday.addingTimeInterval(-600),
    completedAt: localToday.addingTimeInterval(-600),
    durationSeconds: 3_000
  )
  let repository = DashboardSessionRepository(
    snapshots: [TrainingSessionSnapshot(gymDay: "2026-01-17", session: completed)]
  )
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    now: { localToday },
    onOpenTraining: {}
  )

  await viewModel.reload()

  #expect(viewModel.snapshot?.gymDay == "2026-01-17")
  #expect(
    viewModel.status(for: dashboardPlanDay(date: localToday))
      == .completed(durationMinutes: 50)
  )
}

@MainActor
@Test func firstSessionLoadFailureIsUnknownAndLaterFailureKeepsKnownState() async {
  let now = Date(timeIntervalSince1970: 1_768_732_800)
  let completed = TrainingSession(
    status: .completed,
    startedAt: now.addingTimeInterval(-600),
    lastSetAt: now,
    completedAt: now,
    durationSeconds: 600
  )
  let firstFailure = DashboardSessionRepository(snapshots: [], failureCount: 1)
  let unknown = DashboardTrainingStatusViewModel(
    sessions: firstFailure,
    now: { now },
    onOpenTraining: {}
  )
  await unknown.reload()
  #expect(unknown.status(for: dashboardPlanDay(date: now)) == .unknown)

  let center = TrainingSessionActivityCenter()
  let flaky = DashboardSessionRepository(
    snapshots: [TrainingSessionSnapshot(gymDay: "2026-01-18", session: completed)],
    failureCount: 1,
    failAfterSnapshots: true
  )
  let retained = DashboardTrainingStatusViewModel(
    sessions: flaky,
    sessionActivityCenter: center,
    now: { now },
    onOpenTraining: {}
  )
  await retained.reload()
  center.storeAuthoritative(nil)
  await retained.reload()
  #expect(retained.status(for: dashboardPlanDay(date: now)) == .completed(durationMinutes: 10))
}

@MainActor
@Test func foregroundActivationReloadsDashboardSessionStatus() async {
  let repository = DashboardSessionRepository(session: nil)
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    onOpenTraining: {}
  )

  await viewModel.scenePhaseChanged(to: .background)
  #expect(await repository.fetchCallCount == 0)
  await viewModel.scenePhaseChanged(to: .active)
  #expect(await repository.fetchCallCount == 1)
}

@MainActor
@Test func dashboardTrainingTimerAdvancesWithFakeClock() async {
  let start = Date(timeIntervalSince1970: 1_768_732_800)
  let clock = DashboardFakeClock(start)
  let session = TrainingSession(
    status: .inProgress,
    startedAt: start,
    lastSetAt: start,
    completedAt: nil,
    durationSeconds: 0
  )
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: DashboardSessionRepository(session: session),
    now: { clock.now() },
    onOpenTraining: {}
  )
  await viewModel.reload()

  clock.advance(by: 61)
  viewModel.tick()

  #expect(viewModel.status(for: dashboardPlanDay(date: start)) == .inProgress(elapsedSeconds: 61))
  #expect(
    viewModel.status(for: dashboardPlanDay(date: start)).accessibilityText
      == "训练中 · 1:01")
}

@MainActor
@Test func dashboardStatusTapOnlyInvokesTrainingNavigation() async {
  var openedTraining = false
  let repository = DashboardSessionRepository(session: nil)
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    onOpenTraining: { openedTraining = true }
  )

  await viewModel.reload()
  viewModel.openTraining()

  #expect(openedTraining)
  #expect(await repository.startCallCount() == 0)
}

private actor DashboardSessionRepository: TrainingSessionRepository {
  private var snapshots: [TrainingSessionSnapshot]
  private var failureCount: Int
  private let failAfterSnapshots: Bool
  private var starts = 0
  private(set) var fetchCallCount = 0

  init(session: TrainingSession?) {
    self.snapshots = [TrainingSessionSnapshot(gymDay: "2026-01-18", session: session)]
    self.failureCount = 0
    self.failAfterSnapshots = false
  }

  init(
    snapshots: [TrainingSessionSnapshot],
    failureCount: Int = 0,
    failAfterSnapshots: Bool = false
  ) {
    self.snapshots = snapshots
    self.failureCount = failureCount
    self.failAfterSnapshots = failAfterSnapshots
  }

  func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    fetchCallCount += 1
    if !failAfterSnapshots, failureCount > 0 {
      failureCount -= 1
      throw DashboardSessionError()
    }
    if !snapshots.isEmpty {
      return snapshots.removeFirst()
    }
    if failureCount > 0 {
      failureCount -= 1
      throw DashboardSessionError()
    }
    return TrainingSessionSnapshot(gymDay: "2026-01-18", session: nil)
  }

  func startSession() async throws -> TrainingSessionSnapshot {
    starts += 1
    return snapshots.first ?? TrainingSessionSnapshot(gymDay: "2026-01-18", session: nil)
  }

  func markCompleted(date: Date, duration: Int) async {}

  func recentCompletedSession(before date: Date) async -> TrainingSession? { nil }

  func startCallCount() -> Int { starts }
}

private struct DashboardSessionError: Error {}

private final class DashboardFakeClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date: Date

  init(_ date: Date) {
    self.date = date
  }

  func now() -> Date {
    lock.withLock { date }
  }

  func advance(by interval: TimeInterval) {
    lock.withLock {
      date = date.addingTimeInterval(interval)
    }
  }
}

private func dashboardPlanDay(date: Date) -> StudentPlanDay {
  StudentPlanDay(
    id: UUID(),
    date: date,
    exercises: [
      dashboardExercise(name: "比赛式卧推", family: .bench, setCount: 4),
      dashboardExercise(name: "比赛式硬拉", family: .deadlift, setCount: 5),
    ]
  )
}

private func dashboardExercise(
  name: String,
  family: LiftFamily,
  setCount: Int
) -> StudentPlanExercise {
  StudentPlanExercise(
    id: UUID(),
    exercise: Exercise(
      id: UUID(),
      name: name,
      exerciseType: .mainLift,
      mainLiftFamily: family,
      isCompetitionLift: true,
      muscleGroups: [],
      equipment: [.barbell],
      createdAt: Date(timeIntervalSince1970: 1_768_732_800)
    ),
    sequenceIndex: family == .bench ? 0 : 1,
    prescribedSets: (0..<setCount).map { index in
      PrescribedSet(id: UUID(), setIndex: index, weightKg: 100, reps: 5)
    }
  )
}
