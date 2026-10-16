import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func optimisticCenterStillFetchesAndNullResponseDoesNotDowngrade() async {
  let now = Date(timeIntervalSince1970: 1_768_732_800)
  let optimistic = TrainingSession(
    status: .inProgress,
    startedAt: now.addingTimeInterval(-90),
    lastSetAt: now,
    completedAt: nil,
    durationSeconds: 0
  )
  let center = TrainingSessionActivityCenter()
  center.storeOptimisticInProgress(
    TrainingSessionSnapshot(gymDay: nil, session: optimistic)
  )
  let repository = ReconciliationDashboardSessionRepository(
    snapshot: TrainingSessionSnapshot(gymDay: "2026-01-18", session: nil)
  )
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    sessionActivityCenter: center,
    now: { now },
    onOpenTraining: {}
  )

  await viewModel.reload()

  #expect(await repository.fetchCallCount == 1)
  #expect(
    viewModel.status(for: reconciliationPlanDay(date: now)) == .inProgress(elapsedSeconds: 90))
  #expect(center.snapshot?.session == optimistic)
  #expect(center.snapshot?.gymDay == "2026-01-18")
}

@MainActor
@Test func nonNullServerSessionReplacesOptimisticCenterSnapshot() async {
  let now = Date(timeIntervalSince1970: 1_768_732_800)
  let optimistic = TrainingSession(
    status: .inProgress,
    startedAt: now,
    lastSetAt: now,
    completedAt: nil,
    durationSeconds: 0
  )
  let authoritative = TrainingSession(
    status: .completed,
    startedAt: now.addingTimeInterval(-1_800),
    lastSetAt: now,
    completedAt: now,
    durationSeconds: 1_800
  )
  let center = TrainingSessionActivityCenter()
  center.storeOptimisticInProgress(
    TrainingSessionSnapshot(gymDay: nil, session: optimistic)
  )
  let repository = ReconciliationDashboardSessionRepository(
    snapshot: TrainingSessionSnapshot(gymDay: "2026-01-18", session: authoritative)
  )
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    sessionActivityCenter: center,
    now: { now },
    onOpenTraining: {}
  )

  await viewModel.reload()

  #expect(await repository.fetchCallCount == 1)
  #expect(
    viewModel.status(for: reconciliationPlanDay(date: now)) == .completed(durationMinutes: 30))
  #expect(center.snapshot?.session == authoritative)
  #expect(center.holdsOptimisticInProgress == false)
}

@MainActor
@Test func crossoverStripUsesServerGymDayPlanInsteadOfLocalCalendarDay() async throws {
  let calendar = Calendar.current
  let localNow = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 1, day: 18, hour: 2))
  )
  let yesterday = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 1, day: 17))
  )
  let today = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 1, day: 18))
  )
  let yesterdayPlan = reconciliationPlanDay(
    date: yesterday,
    familiesAndSets: [(.squat, 3), (.bench, 4), (.deadlift, 5)]
  )
  let todayPlan = reconciliationPlanDay(date: today, familiesAndSets: [(.bench, 4)])
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: ReconciliationDashboardSessionRepository(
      snapshot: TrainingSessionSnapshot(gymDay: "2026-01-17", session: nil)
    ),
    now: { localNow },
    onOpenTraining: {}
  )

  await viewModel.reload()
  let stripDay = DashboardView.trainingStatusDay(
    in: [yesterdayPlan, todayPlan],
    displayDate: viewModel.displayDate,
    calendar: calendar
  )

  #expect(stripDay?.id == yesterdayPlan.id)
  #expect(viewModel.status(for: stripDay) == .notStarted(dayName: "SBD 日", setCount: 12))
}

@MainActor
@Test func staleOverlappingReloadCannotOverwriteNewerSessionState() async {
  let now = Date(timeIntervalSince1970: 1_768_732_800)
  let completed = TrainingSession(
    status: .completed,
    startedAt: now.addingTimeInterval(-1_800),
    lastSetAt: now,
    completedAt: now,
    durationSeconds: 1_800
  )
  let repository = GatedDashboardSessionRepository(responses: [
    TrainingSessionSnapshot(gymDay: "2026-01-18", session: nil),
    TrainingSessionSnapshot(gymDay: "2026-01-18", session: completed),
  ])
  let center = TrainingSessionActivityCenter()
  let viewModel = DashboardTrainingStatusViewModel(
    sessions: repository,
    sessionActivityCenter: center,
    now: { now },
    onOpenTraining: {}
  )

  // Request A (stale null) is issued first but held; request B (completed)
  // is issued second and resolves first. A's late resolution must be dropped.
  let staleReload = Task { await viewModel.reload() }
  while await repository.pendingCount != 1 { await Task.yield() }
  let freshReload = Task { await viewModel.reload() }
  while await repository.pendingCount != 2 { await Task.yield() }
  await repository.release(index: 1)
  await freshReload.value
  #expect(
    viewModel.status(for: reconciliationPlanDay(date: now)) == .completed(durationMinutes: 30))
  await repository.release(index: 0)
  await staleReload.value

  #expect(
    viewModel.status(for: reconciliationPlanDay(date: now)) == .completed(durationMinutes: 30))
  #expect(center.snapshot?.session == completed)
}

private actor GatedDashboardSessionRepository: TrainingSessionRepository {
  private let responses: [TrainingSessionSnapshot]
  private var continuations: [Int: CheckedContinuation<TrainingSessionSnapshot, Never>] = [:]
  private var issued = 0

  init(responses: [TrainingSessionSnapshot]) {
    self.responses = responses
  }

  var pendingCount: Int { continuations.count }

  func release(index: Int) {
    continuations.removeValue(forKey: index)?.resume(returning: responses[index])
  }

  func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    let index = issued
    issued += 1
    return await withCheckedContinuation { continuation in
      continuations[index] = continuation
    }
  }

  func startSession() async throws -> TrainingSessionSnapshot {
    responses[0]
  }
  func markCompleted(date: Date, duration: Int) async {}
  func recentCompletedSession(before date: Date) async -> TrainingSession? { nil }
}

private actor ReconciliationDashboardSessionRepository: TrainingSessionRepository {
  let snapshot: TrainingSessionSnapshot
  private(set) var fetchCallCount = 0

  init(snapshot: TrainingSessionSnapshot) {
    self.snapshot = snapshot
  }

  func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    fetchCallCount += 1
    return snapshot
  }

  func startSession() async throws -> TrainingSessionSnapshot { snapshot }
  func markCompleted(date: Date, duration: Int) async {}
  func recentCompletedSession(before date: Date) async -> TrainingSession? { nil }
}

private func reconciliationPlanDay(
  date: Date,
  familiesAndSets: [(family: LiftFamily, setCount: Int)] = []
) -> StudentPlanDay {
  StudentPlanDay(
    id: UUID(),
    date: date,
    exercises: familiesAndSets.enumerated().map { index, item in
      StudentPlanExercise(
        id: UUID(),
        exercise: Exercise(
          id: UUID(),
          name: item.family.studentDisplayName,
          exerciseType: .mainLift,
          mainLiftFamily: item.family,
          isCompetitionLift: true,
          muscleGroups: [],
          equipment: [.barbell],
          createdAt: date
        ),
        sequenceIndex: index,
        prescribedSets: (0..<item.setCount).map { setIndex in
          PrescribedSet(id: UUID(), setIndex: setIndex, weightKg: 100, reps: 5)
        }
      )
    }
  )
}
