import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutSessionTests {
  private let now = Date(timeIntervalSince1970: 1_768_262_400)

  @Test func nullSessionRoutesToOverview() async {
    let repository = StubTrainingSessionRepository(fetched: nil)
    let viewModel = await makeViewModel(sessions: repository)

    #expect(viewModel.sessionPage == .overview)
  }

  @Test func inProgressSessionRoutesToWorkout() async {
    let session = makeSession(status: .inProgress)
    let repository = StubTrainingSessionRepository(fetched: session)
    let viewModel = await makeViewModel(sessions: repository)

    #expect(viewModel.sessionPage == .inProgress(session))
  }

  @Test func completedSessionRoutesToExistingReviewState() async {
    let session = makeSession(status: .completed)
    let repository = StubTrainingSessionRepository(fetched: session)
    let viewModel = await makeViewModel(sessions: repository)

    #expect(viewModel.sessionPage == .completed(session))
  }

  @Test func timerUsesInjectedClockAndCompletedDurationIsFrozen() {
    let active = makeSession(status: .inProgress)
    let activePage = TodayWorkoutSessionPage.inProgress(active)
    let completed = makeSession(status: .completed)
    let completedPage = TodayWorkoutSessionPage.completed(completed)

    #expect(TrainingSessionTimer.elapsedSeconds(for: activePage, now: now) == 600)
    #expect(
      TrainingSessionTimer.elapsedSeconds(
        for: completedPage,
        now: now.addingTimeInterval(9_999)
      ) == completed.durationSeconds
    )
    #expect(TrainingSessionTimer.text(seconds: 3_723) == "62:03")
  }

  @Test func startFailureKeepsLocalWorkoutAndRetriesOnce() async {
    let repository = StubTrainingSessionRepository(
      fetched: nil,
      startOutcomes: [.failure, .failure]
    )
    let viewModel = await makeViewModel(sessions: repository)

    await viewModel.startSession()

    guard case .inProgress(let session) = viewModel.sessionPage else {
      Issue.record("Expected local in-progress page after start failure")
      return
    }
    #expect(session.startedAt == now)
    #expect(await repository.startCallCount == 2)
  }

  @Test func immediateReloadWithNullGetKeepsLocalPendingSession() async {
    let serverSession = TrainingSession(
      status: .inProgress,
      startedAt: now.addingTimeInterval(1),
      lastSetAt: now.addingTimeInterval(1),
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetched: nil,
      startOutcomes: [.suspendedSuccess(snapshot(session: serverSession))]
    )
    let viewModel = await makeViewModel(sessions: repository)

    let startTask = Task { await viewModel.startSession() }
    while await repository.startCallCount == 0 {
      await Task.yield()
    }
    await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

    guard case .inProgress(let session) = viewModel.sessionPage else {
      Issue.record("Expected pending local session to survive a null reload")
      return
    }
    #expect(session.startedAt == now)

    await repository.releaseSuspendedStart()
    await startTask.value
    #expect(viewModel.sessionPage == .inProgress(serverSession))
  }

  @Test func finalSetFreezesTheLocallyStartedTimer() async {
    let startedAt = now.addingTimeInterval(-600)
    let repository = StubTrainingSessionRepository(
      fetched: TrainingSession(
        status: .inProgress,
        startedAt: startedAt,
        lastSetAt: startedAt,
        completedAt: nil,
        durationSeconds: 0
      ))
    let viewModel = await makeViewModel(sessions: repository)
    guard case .loaded(_, let drafts) = viewModel.state else {
      Issue.record("Expected loaded workout")
      return
    }

    for index in drafts.indices {
      await viewModel.commitSet(rowIndex: index)
    }

    guard case .completed(let session) = viewModel.sessionPage else {
      Issue.record("Expected completed session after final set")
      return
    }
    #expect(session.durationSeconds == 600)
    #expect(viewModel.sessionElapsedSeconds(at: now.addingTimeInterval(5_000)) == 600)
  }

  @Test func inMemoryCompletionSurvivesLeavingAndReenteringTrainingTab() async {
    let repository = InMemoryTrainingSessionRepository(now: { now })
    let viewModel = await makeViewModel(sessions: repository)
    await viewModel.startSession()
    guard case .loaded(_, let drafts) = viewModel.state else {
      Issue.record("Expected loaded workout")
      return
    }

    for index in drafts.indices {
      await viewModel.commitSet(rowIndex: index)
    }
    await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

    guard case .completed(let session) = viewModel.sessionPage else {
      Issue.record("Expected completed demo session after tab reload")
      return
    }
    #expect(session.durationSeconds == 0)
  }

  @Test func completedDurationPersistsAcrossViewModelColdStart() async throws {
    let suiteName = "TodayWorkoutSessionTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSessionDurationStore(suiteName: suiteName)
    let startedAt = now.addingTimeInterval(-600)
    let firstRepository = StubTrainingSessionRepository(
      fetched: TrainingSession(
        status: .inProgress,
        startedAt: startedAt,
        lastSetAt: startedAt,
        completedAt: nil,
        durationSeconds: 0
      ))
    let firstViewModel = await makeViewModel(
      sessions: firstRepository,
      recentCompletedDurationStore: store
    )
    guard case .loaded(_, let drafts) = firstViewModel.state else {
      Issue.record("Expected loaded workout")
      return
    }
    for index in drafts.indices {
      await firstViewModel.commitSet(rowIndex: index)
    }

    let relaunchedViewModel = await makeViewModel(
      sessions: StubTrainingSessionRepository(fetched: nil),
      recentCompletedDurationStore: UserDefaultsSessionDurationStore(
        suiteName: suiteName)
    )

    #expect(relaunchedViewModel.lastCompletedDurationSeconds == 600)
  }

  private func makeViewModel(
    sessions: any TrainingSessionRepository,
    recentCompletedDurationStore: any RecentCompletedSessionDurationStoring =
      DiscardingSessionDurationStore()
  ) async -> TodayWorkoutViewModel {
    let studentID = StudentDemoSeed.studentID
    let plan = StudentDemoSeed.makePlanView()
    let store = TestStudentPlanStore(seed: [studentID: plan])
    let viewModel = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: store),
      logs: InMemoryStudentTrainingLogRepository(),
      sessions: sessions,
      recentCompletedDurationStore: recentCompletedDurationStore,
      now: { now }
    )
    await viewModel.load(date: Date(), studentID: studentID)
    return viewModel
  }

  private func makeSession(status: TrainingSessionStatus) -> TrainingSession {
    let startedAt = now.addingTimeInterval(-600)
    return TrainingSession(
      status: status,
      startedAt: startedAt,
      lastSetAt: now.addingTimeInterval(-30),
      completedAt: status == .completed ? now.addingTimeInterval(-30) : nil,
      durationSeconds: 570
    )
  }
}

actor StubTrainingSessionRepository: TrainingSessionRepository {
  enum FetchOutcome: Sendable {
    case success(TrainingSessionSnapshot)
    case failure
  }

  enum StartOutcome: Sendable {
    case success(TrainingSessionSnapshot)
    case suspendedSuccess(TrainingSessionSnapshot)
    case failure
  }

  private var fetchOutcomes: [FetchOutcome]
  private var startOutcomes: [StartOutcome]
  private(set) var startCallCount = 0
  private(set) var markedCompleted: (date: Date, duration: Int)?
  private var suspendedStartReleased = false

  init(
    fetched: TrainingSession?,
    gymDay: String? = "2026-01-13",
    startOutcomes: [StartOutcome] = []
  ) {
    self.fetchOutcomes = [.success(snapshot(gymDay: gymDay, session: fetched))]
    self.startOutcomes = startOutcomes
  }

  init(
    fetchedSessions: [TrainingSession?],
    gymDay: String? = "2026-01-13",
    startOutcomes: [StartOutcome] = []
  ) {
    self.fetchOutcomes = fetchedSessions.map {
      .success(snapshot(gymDay: gymDay, session: $0))
    }
    self.startOutcomes = startOutcomes
  }

  init(
    fetchedSnapshots: [TrainingSessionSnapshot],
    startOutcomes: [StartOutcome] = []
  ) {
    self.fetchOutcomes = fetchedSnapshots.map(FetchOutcome.success)
    self.startOutcomes = startOutcomes
  }

  init(
    fetchOutcomes: [FetchOutcome],
    startOutcomes: [StartOutcome] = []
  ) {
    self.fetchOutcomes = fetchOutcomes
    self.startOutcomes = startOutcomes
  }

  func fetchSession(on date: Date?) async throws -> TrainingSessionSnapshot {
    guard !fetchOutcomes.isEmpty else { return snapshot(session: nil) }
    let outcome: FetchOutcome
    if fetchOutcomes.count == 1 {
      outcome = fetchOutcomes[0]
    } else {
      outcome = fetchOutcomes.removeFirst()
    }
    switch outcome {
    case .success(let fetchedSnapshot):
      return fetchedSnapshot
    case .failure:
      throw StubSessionError()
    }
  }

  func startSession() async throws -> TrainingSessionSnapshot {
    startCallCount += 1
    guard !startOutcomes.isEmpty else { throw StubSessionError() }
    switch startOutcomes.removeFirst() {
    case .success(let startedSnapshot):
      return startedSnapshot
    case .suspendedSuccess(let startedSnapshot):
      while !suspendedStartReleased {
        await Task.yield()
      }
      return startedSnapshot
    case .failure:
      throw StubSessionError()
    }
  }

  func recentCompletedSession(before date: Date) async -> TrainingSession? {
    nil
  }

  func markCompleted(date: Date, duration: Int) async {
    markedCompleted = (date, duration)
  }

  func releaseSuspendedStart() {
    suspendedStartReleased = true
  }
}

struct StubSessionError: Error {}

func snapshot(
  gymDay: String? = "2026-01-13",
  session: TrainingSession?
) -> TrainingSessionSnapshot {
  TrainingSessionSnapshot(gymDay: gymDay, session: session)
}

struct DiscardingSessionDurationStore: RecentCompletedSessionDurationStoring {
  func durationSeconds(studentID: UUID) -> Int? { nil }
  func record(durationSeconds: Int, studentID: UUID) {}
}
