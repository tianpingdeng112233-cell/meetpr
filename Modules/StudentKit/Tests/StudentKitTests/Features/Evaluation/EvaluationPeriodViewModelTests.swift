import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

private enum EvaluationFixtures {
  static let now = Date(timeIntervalSince1970: 1_781_000_000)
  static let studentID = UUID(uuidString: "03300000-0000-0000-0000-000000001101")!

  static func period(
    expectedEndAt: Date = now.addingTimeInterval((4 * 24 + 13) * 3_600),
    completedAt: Date? = nil
  ) -> EvaluationPeriod {
    EvaluationPeriod(
      id: UUID(uuidString: "03300000-0000-0000-0000-000000001201")!,
      studentId: studentID,
      coachId: UUID(),
      bindRequestId: UUID(),
      startedAt: expectedEndAt.addingTimeInterval(-7 * 86_400),
      expectedEndAt: expectedEndAt,
      completedAt: completedAt,
      completionType: completedAt == nil ? nil : "coach_completed",
      inProgress: completedAt == nil,
      overdue: false
    )
  }

  static func feedback(text: String, offset: TimeInterval) -> CoachFeedback {
    CoachFeedback(
      id: UUID(),
      coachID: UUID(),
      studentID: studentID,
      text: text,
      postedAt: now.addingTimeInterval(offset),
      readAt: nil
    )
  }
}

private actor StubMyEvaluationRepository: EvaluationRepository {
  var period: EvaluationPeriod?
  var error: Error?

  init(period: EvaluationPeriod?, error: Error? = nil) {
    self.period = period
    self.error = error
  }

  func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? { period }

  func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    if let error { throw error }
    return period
  }

  func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    throw EvaluationError.notFound
  }
}

private actor StubPlanRepository: StudentPlanRepository {
  var plan: StudentPlanView?

  init(plan: StudentPlanView? = nil) {
    self.plan = plan
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { plan }
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? { nil }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { plan?.days ?? [] }
}

private actor StubInboxRepository: StudentFeedbackRepository {
  var inbox: [CoachFeedback]

  init(inbox: [CoachFeedback] = []) {
    self.inbox = inbox
  }

  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] { inbox }

  func postFeedback(
    studentID: UUID, dayDate: Date?, planExerciseID: UUID?, text: String
  ) async throws -> CoachFeedback {
    EvaluationFixtures.feedback(text: text, offset: 0)
  }

  func markRead(feedbackID: UUID) async throws {}
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeViewModel(
  evaluations: StubMyEvaluationRepository,
  plans: StubPlanRepository = StubPlanRepository(),
  feedback: StubInboxRepository = StubInboxRepository(),
  onCompleted: @escaping @MainActor () async -> Void = {}
) -> EvaluationPeriodViewModel {
  EvaluationPeriodViewModel(
    studentID: EvaluationFixtures.studentID,
    evaluations: evaluations,
    plans: plans,
    feedback: feedback,
    onCompleted: onCompleted
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func activeEvaluationShowsCountdownAndProgress() async {
  let period = EvaluationFixtures.period()
  let viewModel = makeViewModel(evaluations: StubMyEvaluationRepository(period: period))

  await viewModel.refresh()

  #expect(viewModel.state == .active(period))
  #expect(
    viewModel.countdownText(now: EvaluationFixtures.now) == "评估期还剩: 4 天 13 小时")
  let progress = viewModel.progress(now: EvaluationFixtures.now)
  #expect(progress > 0.3 && progress < 0.4)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func overdueShowsNeutralClosingCopyWithoutNegativeHint() async {
  let period = EvaluationFixtures.period(
    expectedEndAt: EvaluationFixtures.now.addingTimeInterval(-2 * 86_400))
  let viewModel = makeViewModel(evaluations: StubMyEvaluationRepository(period: period))

  await viewModel.refresh()

  let text = viewModel.countdownText(now: EvaluationFixtures.now)
  #expect(text == "评估即将完成")
  // wiki §4.4 决议 1.5: the student never sees overdue wording.
  #expect(!text.contains("超期"))
  #expect(viewModel.progress(now: EvaluationFixtures.now) == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completedEvaluationFiresHandoffInsteadOfRendering() async {
  let period = EvaluationFixtures.period(
    completedAt: EvaluationFixtures.now.addingTimeInterval(-3_600))
  var handedOff = false
  let viewModel = makeViewModel(
    evaluations: StubMyEvaluationRepository(period: period),
    onCompleted: { handedOff = true }
  )

  await viewModel.refresh()

  #expect(handedOff)
  #expect(viewModel.state == .loading)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func missingEvaluationAlsoFiresHandoff() async {
  var handedOff = false
  let viewModel = makeViewModel(
    evaluations: StubMyEvaluationRepository(period: nil),
    onCompleted: { handedOff = true }
  )

  await viewModel.refresh()

  #expect(handedOff)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblesLatestThreeMessagesAndAdaptationEntry() async {
  let inbox = [
    EvaluationFixtures.feedback(text: "第一条", offset: -4_000),
    EvaluationFixtures.feedback(text: "第二条", offset: -3_000),
    EvaluationFixtures.feedback(text: "第三条", offset: -2_000),
    EvaluationFixtures.feedback(text: "最新", offset: -1_000),
  ]
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: EvaluationFixtures.now,
    planKind: .adaptation,
    days: [
      StudentPlanDay(
        id: UUID(),
        date: EvaluationFixtures.now,
        exercises: []
      )
    ]
  )
  let viewModel = makeViewModel(
    evaluations: StubMyEvaluationRepository(period: EvaluationFixtures.period()),
    plans: StubPlanRepository(plan: plan),
    feedback: StubInboxRepository(inbox: inbox)
  )

  await viewModel.refresh()

  #expect(viewModel.latestMessages.map(\.text) == ["最新", "第三条", "第二条"])
  #expect(viewModel.adaptationPlan != nil)
  // All days empty → no trainable session yet → waiting copy.
  #expect(!viewModel.hasAdaptationTraining)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func transportFailureOnFirstLoadShowsRetryState() async {
  struct TransportError: Error {}
  let viewModel = makeViewModel(
    evaluations: StubMyEvaluationRepository(period: nil, error: TransportError()))

  await viewModel.refresh()

  #expect(viewModel.state == .failed)
}
