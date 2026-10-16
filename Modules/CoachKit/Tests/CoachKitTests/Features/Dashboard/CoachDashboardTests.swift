import CoreModels
import DesignSystem
import Foundation
import Networking
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Test func signalRowsRenderAllThreeTypeLabelsAndMapDotColors() throws {
  let cases: [SignalPresentationCase] = [
    SignalPresentationCase(
      type: .missedTraining,
      severity: .red,
      label: "缺练",
      color: Color.MeetPR.brandRed
    ),
    SignalPresentationCase(
      type: .weightFailed,
      severity: .yellow,
      label: "被压",
      color: Color.MeetPR.signalYellow
    ),
    SignalPresentationCase(
      type: .personalRecord,
      severity: .green,
      label: "PR",
      color: Color.MeetPR.green
    ),
  ]

  for item in cases {
    let signal = coachSignal(type: item.type, severity: item.severity)
    let inspected = try CoachSignalRow(signal: signal, showsTopBorder: false).inspect()
    #expect(try inspected.find(text: item.label).string() == item.label)
    #expect(item.severity.dotColor == item.color)
  }
}

@MainActor
@Test func dashboardShowsSignalEmptyStateAfterLegacyTriageRetirement() async throws {
  let viewModel = CoachDashboardViewModel(repository: InMemoryCoachDashboardRepository())
  await viewModel.reload()
  let inspected = try CoachDashboardView(
    attentionCount: 2,
    pendingCount: 0,
    context: try dashboardContext(),
    rows: [],
    viewModel: viewModel
  ).inspect()

  #expect(
    try inspected.find(text: "今天没有需要你处理的学员").string()
      == "今天没有需要你处理的学员")
  #expect(throws: (any Error).self) {
    try inspected.find(text: "学员 — 今日")
  }
}

@Test func backendDigestGateHidesNullBody() async {
  let repository = BackendCoachDashboardRepository(
    api: digestClient(statusCode: 200, body: SelfTestDigest.nullBody),
    session: CoachDashboardTestSession()
  )

  #expect(await repository.fetchDailyDigestBody() == nil)
}

@Test func backendDigestGateHidesRequestFailure() async {
  let repository = BackendCoachDashboardRepository(
    api: digestClient(statusCode: 503, body: #"{"error":"UNAVAILABLE"}"#),
    session: CoachDashboardTestSession()
  )

  #expect(await repository.fetchDailyDigestBody() == nil)
}

@MainActor
@Test func dashboardViewModelDefensivelySortsSeverityThenNewestFirst() async {
  let oldest = Date(timeIntervalSince1970: 1_768_732_700)
  let newest = Date(timeIntervalSince1970: 1_768_732_900)
  let seed = [
    coachSignal(type: .personalRecord, severity: .green, openedAt: newest),
    coachSignal(type: .weightFailed, severity: .yellow, openedAt: oldest),
    coachSignal(type: .missedTraining, severity: .red, openedAt: oldest),
    coachSignal(type: .weightFailed, severity: .yellow, openedAt: newest),
  ]
  let viewModel = CoachDashboardViewModel(
    repository: InMemoryCoachDashboardRepository(
      signals: seed,
      dailyDigestBody: CoachDemoSeed.dailyDigestBody
    )
  )

  await viewModel.reload()

  #expect(viewModel.signals.map(\.severity) == [.red, .yellow, .yellow, .green])
  #expect(viewModel.signals.map(\.openedAt) == [oldest, newest, oldest, newest])
  #expect(viewModel.dailyDigestBody == CoachDemoSeed.dailyDigestBody)
}

@MainActor
@Test func dashboardSignalFailureRendersRetryInsteadOfGreenEmptyState() async throws {
  let viewModel = CoachDashboardViewModel(repository: FailingCoachDashboardRepository())
  await viewModel.reload()

  #expect(viewModel.loadState == .failed)
  let inspected = try CoachDashboardView(
    attentionCount: 0,
    pendingCount: 0,
    context: try dashboardContext(),
    viewModel: viewModel
  ).inspect()
  #expect(
    try inspected.find(text: "信号加载失败,下拉重试").string()
      == "信号加载失败,下拉重试")
  #expect(throws: (any Error).self) {
    try inspected.find(text: "今天没有需要你处理的学员")
  }
}

@MainActor
@Test func signalTitleNeverUsesStaleCountWhileLoadingOrFailed() async throws {
  let staleSignal = coachSignal(type: .missedTraining, severity: .red)
  let repository = FlakyCoachDashboardRepository(firstSignals: [staleSignal])
  let viewModel = CoachDashboardViewModel(repository: repository)

  let loadingView = try CoachDashboardView(
    attentionCount: 0,
    pendingCount: 0,
    context: dashboardContext(),
    viewModel: viewModel
  ).inspect()
  #expect(try loadingView.find(text: "信号").string() == "信号")

  await viewModel.reload()
  await viewModel.reload()
  #expect(viewModel.loadState == .failed)
  #expect(viewModel.signals.count == 1)

  let failedView = try CoachDashboardView(
    attentionCount: 0,
    pendingCount: 0,
    context: dashboardContext(),
    viewModel: viewModel
  ).inspect()
  #expect(try failedView.find(text: "信号").string() == "信号")
  #expect(throws: (any Error).self) {
    try failedView.find(text: "今天 1 个需要你")
  }
}

@MainActor
@Test func concurrentDashboardInitialLoadsShareOneRequest() async {
  let repository = GatedCoachDashboardRepository()
  let viewModel = CoachDashboardViewModel(repository: repository)

  let first = Task { await viewModel.loadIfNeeded() }
  while await repository.signalCallCount == 0 {
    await Task.yield()
  }
  let second = Task { await viewModel.loadIfNeeded() }
  await repository.release()
  await first.value
  await second.value

  #expect(await repository.signalCallCount == 1)
  #expect(viewModel.loadState == .loaded)
}

private func coachSignal(
  type: CoachSignalType,
  severity: CoachSignalSeverity,
  openedAt: Date = Date(timeIntervalSince1970: 1_768_732_800)
) -> CoachSignal {
  CoachSignal(
    id: UUID(),
    studentID: UUID(),
    studentName: "测试学员",
    type: type,
    severity: severity,
    reason: "这是一条足够具体的留因说明",
    openedAt: openedAt
  )
}

private struct FailingCoachDashboardRepository: CoachDashboardRepository {
  func fetchOpenSignals() async throws -> [CoachSignal] {
    throw CoachDashboardTestError()
  }

  func fetchDailyDigestBody() async -> String? { nil }
}

private actor GatedCoachDashboardRepository: CoachDashboardRepository {
  private(set) var signalCallCount = 0
  private var isReleased = false

  func fetchOpenSignals() async throws -> [CoachSignal] {
    signalCallCount += 1
    while !isReleased {
      await Task.yield()
    }
    return []
  }

  func fetchDailyDigestBody() async -> String? { nil }

  func release() {
    isReleased = true
  }
}

private actor FlakyCoachDashboardRepository: CoachDashboardRepository {
  private let firstSignals: [CoachSignal]
  private var callCount = 0

  init(firstSignals: [CoachSignal]) {
    self.firstSignals = firstSignals
  }

  func fetchOpenSignals() async throws -> [CoachSignal] {
    callCount += 1
    if callCount == 1 { return firstSignals }
    throw CoachDashboardTestError()
  }

  func fetchDailyDigestBody() async -> String? { nil }
}

private struct CoachDashboardTestError: Error {}

private struct SignalPresentationCase {
  let type: CoachSignalType
  let severity: CoachSignalSeverity
  let label: String
  let color: Color
}

@MainActor
private func dashboardContext() throws -> CoachStudentDetailContext {
  CoachStudentDetailContext(
    plans: EmptyStudentPlanRepository(),
    trainingLogs: EmptyStudentTrainingLogRepository(),
    feedback: EmptyStudentFeedbackRepository(),
    profiles: InMemoryCoachStudentProfileReader(),
    videos: InMemoryCoachStudentVideoRepository(),
    readiness: EmptyReadinessRepository(),
    familyMapProvider: nil,
    planning: InMemoryPlanRepository(students: [], catalog: []),
    draftStore: try DraftStore.inMemory()
  )
}

private func digestClient(statusCode: Int, body: String) -> APIClient {
  APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { _ in
    APIResponse(data: Data(body.utf8), statusCode: statusCode)
  }
}

private struct CoachDashboardTestSession: SessionStateReader {
  func accessToken() async throws -> String { "token" }

  func currentUser() async throws -> User {
    let now = Date(timeIntervalSince1970: 1_768_732_800)
    return User(
      id: UUID(),
      phone: "13800000000",
      unitSystem: .metric,
      role: .coach,
      createdAt: now,
      updatedAt: now
    )
  }
}

private enum SelfTestDigest {
  static let nullBody = #"""
    {
      "gym_day": "2026-07-17",
      "counts": {
        "session_completed": 0,
        "session_partial": 0,
        "missed_training": 0,
        "weight_failed": 0,
        "pr_e1rm": 0
      },
      "body": null
    }
    """#
}
