import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailDefinesFiveSectionsInSpecOrder() {
  #expect(StudentDetailSection.allCases.map(\.title) == ["概览", "执行", "视频", "成长", "反馈"])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailLoadsExecutionAndFeedbackSummaries() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let plan = CoachStudentFeatureFixtures.plan()
  let log = CoachStudentFeatureFixtures.log()
  let feedback = CoachStudentFeatureFixtures.feedback()
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: plan]),
    trainingLogs: StubTrainingLogRepository(logs: [log]),
    feedback: StubFeedbackRepository(feedback: [feedback]),
    now: { CoachStudentFeatureFixtures.startDate.addingTimeInterval(3 * 86_400) }
  )

  await viewModel.refresh()

  #expect(viewModel.executionDays.count == 7)
  #expect(viewModel.overview.plannedTrainingDays == 1)
  #expect(viewModel.overview.completedTrainingDays == 1)
  #expect(viewModel.feedbackItems.first?.id == feedback.id)
  #expect(viewModel.allPlanExercises.map(\.id) == [CoachStudentFeatureFixtures.planExerciseID])

  viewModel.select(.feedback)
  #expect(viewModel.selectedSection == .feedback)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func detailAppendPostedFeedbackRefreshesLatestOverview() async {
  let summary = CoachStudentFeatureFixtures.summary()
  let older = CoachStudentFeatureFixtures.feedback(
    postedAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(86_400)
  )
  let newer = CoachStudentFeatureFixtures.feedback(
    postedAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(4 * 86_400)
  )
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: CoachStudentFeatureFixtures.plan()]),
    trainingLogs: StubTrainingLogRepository(logs: []),
    feedback: StubFeedbackRepository(feedback: [older])
  )

  await viewModel.refresh()
  viewModel.appendPostedFeedback(newer)

  #expect(viewModel.feedbackItems.first?.id == newer.id)
  #expect(viewModel.overview.latestFeedback?.id == newer.id)
}
