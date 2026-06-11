import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private let baseDate = Date(timeIntervalSince1970: 1_781_000_000)
private let studentID = UUID(uuidString: "03300000-0000-0000-0000-000000002101")!

private func makeSummary(
  trainingPlan: String = "第一周期以技术为主\n第二周期加量\n第三周期冲强度",
  words: String? = "保持节奏",
  lastUpdatedAt: Date = baseDate
) -> EvaluationSummary {
  EvaluationSummary(
    id: UUID(),
    studentId: studentID,
    coachId: UUID(),
    overallAssessment: "底力扎实",
    trainingPlan: trainingPlan,
    wordsToStudent: words,
    firstSavedAt: baseDate.addingTimeInterval(-86_400),
    lastUpdatedAt: lastUpdatedAt,
    isActive: true
  )
}

private func makePlan(kind: PlanKind) -> StudentPlanView {
  StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: baseDate,
    planKind: kind,
    days: []
  )
}

// MARK: - Excerpts

@Test func summaryExcerptsKeepTwoLines() {
  let summary = makeSummary()
  #expect(summary.trainingPlanExcerpt == "第一周期以技术为主\n第二周期加量…")
  #expect(summary.wordsExcerpt == "保持节奏")
  #expect(makeSummary(words: nil).wordsExcerpt == nil)
}

// MARK: - Unread (D7)

@Test func unreadWhenNeverReadOrUpdatedAfterLastRead() {
  let summary = makeSummary()
  #expect(EvaluationSummaryPresentation.isUnread(summary: summary, lastReadAt: nil))
  #expect(
    EvaluationSummaryPresentation.isUnread(
      summary: summary, lastReadAt: baseDate.addingTimeInterval(-60)))
  #expect(
    !EvaluationSummaryPresentation.isUnread(
      summary: summary, lastReadAt: baseDate.addingTimeInterval(60)))
}

// MARK: - "Waiting for first regular plan" row

@Test func awaitsFirstRegularPlanUntilRegularPublished() {
  #expect(EvaluationSummaryPresentation.awaitsFirstRegularPlan(nil))
  #expect(EvaluationSummaryPresentation.awaitsFirstRegularPlan(makePlan(kind: .adaptation)))
  #expect(!EvaluationSummaryPresentation.awaitsFirstRegularPlan(makePlan(kind: .regular)))
}

// MARK: - View model wiring

private actor StubSummaryRepository: EvaluationSummaryRepository {
  let summary: EvaluationSummary?

  init(summary: EvaluationSummary?) {
    self.summary = summary
  }

  func fetchSummary(studentID: UUID) async throws -> EvaluationSummary? { summary }

  func putSummary(
    studentID: UUID,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) async throws -> EvaluationSummary {
    throw EvaluationError.notFound
  }
}

private actor StubPlansRepository: StudentPlanRepository {
  let plan: StudentPlanView?

  init(plan: StudentPlanView?) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { [] }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func dashboardCardShowsWhileUnreadAndCollapsesOnRead() async {
  let store = InMemoryEvaluationSummaryReadStore()
  let viewModel = StudentEvaluationSummaryViewModel(
    summaries: StubSummaryRepository(summary: makeSummary()),
    plans: StubPlansRepository(plan: makePlan(kind: .adaptation)),
    readStore: store,
    now: { baseDate }
  )

  await viewModel.load(studentID: studentID)

  #expect(viewModel.showsDashboardCard)
  #expect(viewModel.unreadBadgeCount == 1)
  #expect(viewModel.showsAwaitingFirstPlan)

  viewModel.markRead()

  #expect(!viewModel.showsDashboardCard)
  #expect(viewModel.unreadBadgeCount == 0)
  #expect(store.lastReadAt(studentID: studentID) != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func noSummaryMeansNoCardNoBadgeNoWaitingRow() async {
  let viewModel = StudentEvaluationSummaryViewModel(
    summaries: StubSummaryRepository(summary: nil),
    plans: StubPlansRepository(plan: nil),
    readStore: InMemoryEvaluationSummaryReadStore(),
    now: { baseDate }
  )

  await viewModel.load(studentID: studentID)

  #expect(!viewModel.showsDashboardCard)
  #expect(viewModel.unreadBadgeCount == 0)
  #expect(!viewModel.showsAwaitingFirstPlan)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func updatedSummaryReFlagsUnreadAfterEarlierRead() async {
  let store = InMemoryEvaluationSummaryReadStore(
    seed: [studentID: baseDate.addingTimeInterval(-3_600)])
  let viewModel = StudentEvaluationSummaryViewModel(
    summaries: StubSummaryRepository(summary: makeSummary(lastUpdatedAt: baseDate)),
    plans: StubPlansRepository(plan: makePlan(kind: .regular)),
    readStore: store,
    now: { baseDate }
  )

  await viewModel.load(studentID: studentID)

  // Coach re-saved after the student's last read → red dot returns.
  #expect(viewModel.showsDashboardCard)
  // A regular plan exists → no waiting row.
  #expect(!viewModel.showsAwaitingFirstPlan)
}
