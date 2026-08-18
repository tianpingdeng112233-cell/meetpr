import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func composerRejectsEmptyText() async {
  let repository = StubFeedbackRepository()
  let viewModel = FeedbackComposerViewModel(
    studentID: CoachStudentFeatureFixtures.studentID,
    repository: repository
  )

  let item = await viewModel.send()

  #expect(item == nil)
  guard case .failed(CoachStudentDetailStrings.text("coach.feedback.error.empty")) = viewModel.state
  else {
    Issue.record("Expected empty-text failure")
    return
  }
  let posted = await repository.postedTexts()
  #expect(posted.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func composerSendsTrimmedTextWithOptionalLinks() async {
  let repository = StubFeedbackRepository()
  let plan = CoachStudentFeatureFixtures.plan()
  let day = plan.days[1]
  let exercise = day.exercises[0]
  let viewModel = FeedbackComposerViewModel(
    studentID: CoachStudentFeatureFixtures.studentID,
    repository: repository
  )
  viewModel.text = "  今天深蹲速度很好  "
  viewModel.selectDay(day.date)
  viewModel.selectExercise(exercise.id)

  let item = await viewModel.send()
  let posted = await repository.postedTexts()

  #expect(item != nil)
  #expect(viewModel.state == .sent)
  #expect(posted == ["今天深蹲速度很好"])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func composerSurfacesSendFailure() async {
  let viewModel = FeedbackComposerViewModel(
    studentID: CoachStudentFeatureFixtures.studentID,
    repository: StubFeedbackRepository(postError: CoachFeatureTestError())
  )
  viewModel.text = "需要补充一句"

  let item = await viewModel.send()

  #expect(item == nil)
  guard case .failed(CoachStudentDetailStrings.text("coach.feedback.error.send")) = viewModel.state
  else {
    Issue.record("Expected send failure")
    return
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func composerClearsExerciseWhenLinkedDayChanges() {
  let repository = StubFeedbackRepository()
  let plan = CoachStudentFeatureFixtures.plan()
  let viewModel = FeedbackComposerViewModel(
    studentID: CoachStudentFeatureFixtures.studentID,
    repository: repository
  )
  viewModel.selectDay(plan.days[1].date)
  viewModel.selectExercise(CoachStudentFeatureFixtures.planExerciseID)

  viewModel.selectDay(plan.days[2].date)
  viewModel.reconcileExerciseSelection(days: plan.days)

  #expect(viewModel.selectedExerciseID == nil)
}
