import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeViewModel(
  evaluations: StubEvaluationRepository,
  summaries: StubEvaluationSummaryRepository = StubEvaluationSummaryRepository()
) -> EvaluationBannerViewModel {
  EvaluationBannerViewModel(
    studentID: BindQueueFixtures.studentID,
    evaluations: evaluations,
    summaries: summaries,
    now: { BindQueueFixtures.now }
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bannerVisibleOnlyForLiveEvaluation() async {
  let live = BindQueueFixtures.evaluation()
  let viewModel = makeViewModel(
    evaluations: StubEvaluationRepository(
      evaluationsByStudent: [BindQueueFixtures.studentID: live]))

  await viewModel.load()

  #expect(viewModel.isBannerVisible)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bannerHiddenWhenNoEvaluationOrCompleted() async {
  let none = makeViewModel(evaluations: StubEvaluationRepository())
  await none.load()
  #expect(!none.isBannerVisible)

  let completed = BindQueueFixtures.evaluation(
    completedAt: BindQueueFixtures.now.addingTimeInterval(-3_600))
  let completedViewModel = makeViewModel(
    evaluations: StubEvaluationRepository(
      evaluationsByStudent: [BindQueueFixtures.studentID: completed]))
  await completedViewModel.load()
  #expect(!completedViewModel.isBannerVisible)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func statusTextCountsDownFromExpectedEnd() async {
  let evaluation = BindQueueFixtures.evaluation(
    expectedEndAt: BindQueueFixtures.now.addingTimeInterval((4 * 24 + 13) * 3_600))
  let viewModel = makeViewModel(
    evaluations: StubEvaluationRepository(
      evaluationsByStudent: [BindQueueFixtures.studentID: evaluation]))
  await viewModel.load()

  #expect(viewModel.statusText(now: BindQueueFixtures.now) == "评估期 · 还剩 4 天 13 小时")
  #expect(!viewModel.isOverdue(now: BindQueueFixtures.now))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func statusTextFlipsToOverdueCopyPastExpectedEnd() async {
  let evaluation = BindQueueFixtures.evaluation(
    startedAt: BindQueueFixtures.now.addingTimeInterval(-9 * 86_400),
    expectedEndAt: BindQueueFixtures.now.addingTimeInterval(-2 * 86_400))
  let viewModel = makeViewModel(
    evaluations: StubEvaluationRepository(
      evaluationsByStudent: [BindQueueFixtures.studentID: evaluation]))
  await viewModel.load()

  #expect(viewModel.statusText(now: BindQueueFixtures.now) == "已超期 2 天,请尽快交付总结")
  #expect(viewModel.isOverdue(now: BindQueueFixtures.now))
  #expect(viewModel.isBannerVisible)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completeHidesBannerOnSuccess() async {
  let evaluation = BindQueueFixtures.evaluation()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation])
  let viewModel = makeViewModel(evaluations: evaluations)
  await viewModel.load()

  let completed = await viewModel.complete()

  #expect(completed)
  #expect(!viewModel.isBannerVisible)
  let completedIDs = await evaluations.completedIDs
  #expect(completedIDs == [evaluation.id])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func concurrentCompleteConflictReadsAsSuccessAndRefreshes() async {
  let evaluation = BindQueueFixtures.evaluation()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation],
    completeError: EvaluationError.alreadyCompleted
  )
  let viewModel = makeViewModel(evaluations: evaluations)
  await viewModel.load()

  let completed = await viewModel.complete()

  // 409 = some other path already completed it: treated as success.
  #expect(completed)
  #expect(viewModel.completeError == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func transportFailureOnCompleteKeepsBannerWithError() async {
  let evaluation = BindQueueFixtures.evaluation()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation],
    completeError: CoachFeatureTestError()
  )
  let viewModel = makeViewModel(evaluations: evaluations)
  await viewModel.load()

  let completed = await viewModel.complete()

  #expect(!completed)
  #expect(viewModel.completeError != nil)
  #expect(viewModel.isBannerVisible)
}
