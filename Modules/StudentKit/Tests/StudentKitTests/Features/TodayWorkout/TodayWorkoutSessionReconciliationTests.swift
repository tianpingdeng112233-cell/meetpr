import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Suite struct TodayWorkoutSessionReconciliationTests {
  private let now = Date(timeIntervalSince1970: 1_768_262_400)

  @Test func olderPostSessionAuthoritativelyReplacesLocalPendingSession() async {
    let olderSession = TrainingSession(
      status: .inProgress,
      startedAt: now.addingTimeInterval(-60),
      lastSetAt: now.addingTimeInterval(-60),
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetched: nil,
      startOutcomes: [.success(snapshot(session: olderSession))]
    )
    let viewModel = await makeViewModel(sessions: repository)

    await viewModel.startSession()

    #expect(viewModel.sessionPage == .inProgress(olderSession))
    #expect(viewModel.localSessionOverride == nil)
  }

  @Test func failedGetThenIdempotentPostCompletedShowsCompletion() async {
    let completedSession = makeSession(status: .completed)
    let repository = StubTrainingSessionRepository(
      fetchOutcomes: [.failure],
      startOutcomes: [.success(snapshot(session: completedSession))]
    )
    let viewModel = await makeViewModel(sessions: repository)

    await viewModel.startSession()

    #expect(viewModel.sessionPage == .completed(completedSession))
    #expect(viewModel.localSessionOverride == nil)
  }

  @Test func newGymDayNullGetDiscardsYesterdayOverrideWithoutStarting() async {
    let yesterdayGymDay = "2026-01-12"
    let todayGymDay = "2026-01-13"
    let yesterdaySession = makeSession(status: .inProgress)
    let repository = StubTrainingSessionRepository(
      fetchedSnapshots: [
        snapshot(gymDay: yesterdayGymDay, session: nil),
        snapshot(gymDay: todayGymDay, session: nil),
      ]
    )
    let viewModel = await makeViewModel(sessions: repository)
    viewModel.localSessionOverride = LocalSessionOverride(
      gymDay: yesterdayGymDay,
      session: yesterdaySession
    )
    viewModel.sessionPage = .inProgress(yesterdaySession)

    await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

    #expect(viewModel.sessionPage == .overview)
    #expect(viewModel.localSessionOverride == nil)
    #expect(await repository.startCallCount == 0)
  }

  @Test func missingGymDayNullGetConservativelyDiscardsOverride() async {
    let completedSession = makeSession(status: .completed)
    let repository = StubTrainingSessionRepository(
      fetchedSnapshots: [
        snapshot(gymDay: "2026-01-12", session: nil),
        snapshot(gymDay: nil, session: nil),
      ]
    )
    let viewModel = await makeViewModel(sessions: repository)
    viewModel.localSessionOverride = LocalSessionOverride(
      gymDay: "2026-01-12",
      session: completedSession
    )
    viewModel.sessionPage = .completed(completedSession)

    await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

    #expect(viewModel.sessionPage == .overview)
    #expect(viewModel.localSessionOverride == nil)
    #expect(await repository.startCallCount == 0)
  }

  private func makeViewModel(
    sessions: any TrainingSessionRepository
  ) async -> TodayWorkoutViewModel {
    let studentID = StudentDemoSeed.studentID
    let plan = StudentDemoSeed.makePlanView()
    let store = TestStudentPlanStore(seed: [studentID: plan])
    let viewModel = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(store: store),
      logs: InMemoryStudentTrainingLogRepository(),
      sessions: sessions,
      recentCompletedDurationStore: DiscardingSessionDurationStore(),
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

  @Test func getIssuedAfterStartAppliesServerTruthEvenWhenOlder() async {
    // POST landed server-side but its response was lost: a reload GET issued
    // AFTER the local start returns the real (earlier-started) session, and
    // that server truth must win over the optimistic local clock.
    let serverTruth = TrainingSession(
      status: .inProgress,
      startedAt: now.addingTimeInterval(-60),
      lastSetAt: now.addingTimeInterval(-60),
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetchedSessions: [nil, serverTruth],
      startOutcomes: [.failure, .failure]
    )
    let viewModel = await makeViewModel(sessions: repository)

    await viewModel.startSession()
    await viewModel.load(date: Date(), studentID: StudentDemoSeed.studentID)

    guard case .inProgress(let session) = viewModel.sessionPage else {
      Issue.record("Expected the authoritative server session to apply")
      return
    }
    #expect(session.startedAt == now.addingTimeInterval(-60))
  }

  @Test func latePostDoesNotRepaintHistoryBrowsing() async {
    let postSession = TrainingSession(
      status: .inProgress,
      startedAt: now,
      lastSetAt: now,
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetchedSessions: [nil, nil],
      startOutcomes: [
        .suspendedSuccess(TrainingSessionSnapshot(gymDay: "2026-01-13", session: postSession))
      ]
    )
    let viewModel = await makeViewModel(sessions: repository)
    // startSession awaits its coordination task, so it must run detached
    // while the stub keeps the POST suspended (same pattern as the existing
    // suspended-start test).
    let startTask = Task { await viewModel.startSession() }
    while await repository.startCallCount == 0 {
      await Task.yield()
    }

    // Navigate to a history date while the start POST is still in flight.
    await viewModel.load(
      date: Date(),
      sessionDate: now.addingTimeInterval(-86_400),
      studentID: StudentDemoSeed.studentID
    )
    let historyPage = viewModel.sessionPage

    await repository.releaseSuspendedStart()
    await startTask.value
    #expect(viewModel.sessionPage == historyPage)
  }

  @Test func getIssuedBeforeStartIsIgnored() async {
    // A GET that raced the local start (issued before, returned after) must
    // not clobber the optimistic state — staleness is a request property.
    let racedSession = TrainingSession(
      status: .inProgress,
      startedAt: now.addingTimeInterval(-60),
      lastSetAt: now.addingTimeInterval(-60),
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetchedSessions: [nil],
      startOutcomes: [.failure, .failure]
    )
    let viewModel = await makeViewModel(sessions: repository)

    await viewModel.startSession()
    await viewModel.applyFetchedSession(
      TrainingSessionSnapshot(gymDay: nil, session: racedSession),
      isToday: true,
      issuedStartGeneration: 0
    )

    guard case .inProgress(let session) = viewModel.sessionPage else {
      Issue.record("Expected the local pending session to survive a raced GET")
      return
    }
    #expect(session.startedAt == now)
  }

  @Test func lateGetCannotClobberPostTruthOrResetToOverview() async {
    // POST succeeded (override cleared, server truth showing). A GET that was
    // issued before the start then returns — as null AND as an older session —
    // and must be dropped entirely: no overview reset, no state rewrite.
    let postSession = TrainingSession(
      status: .inProgress,
      startedAt: now.addingTimeInterval(-30),
      lastSetAt: now.addingTimeInterval(-30),
      completedAt: nil,
      durationSeconds: 0
    )
    let repository = StubTrainingSessionRepository(
      fetchedSessions: [nil],
      startOutcomes: [.success(TrainingSessionSnapshot(gymDay: "2026-01-13", session: postSession))]
    )
    let viewModel = await makeViewModel(sessions: repository)
    await viewModel.startSession()
    guard case TodayWorkoutSessionPage.inProgress(let postTruth) = viewModel.sessionPage
    else {
      Issue.record("Expected POST truth in progress")
      return
    }

    await viewModel.applyFetchedSession(
      TrainingSessionSnapshot(gymDay: nil, session: nil),
      isToday: true,
      issuedStartGeneration: 0
    )
    #expect(viewModel.sessionPage == TodayWorkoutSessionPage.inProgress(postTruth))

    let older = TrainingSession(
      status: .completed,
      startedAt: now.addingTimeInterval(-3_600),
      lastSetAt: now.addingTimeInterval(-3_000),
      completedAt: now.addingTimeInterval(-3_000),
      durationSeconds: 600
    )
    await viewModel.applyFetchedSession(
      TrainingSessionSnapshot(gymDay: nil, session: older),
      isToday: true,
      issuedStartGeneration: 0
    )
    #expect(viewModel.sessionPage == TodayWorkoutSessionPage.inProgress(postTruth))
  }
}
