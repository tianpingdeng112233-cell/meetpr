import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func makeEditor(
  evaluation: EvaluationPeriod?,
  summaries: StubEvaluationSummaryRepository = StubEvaluationSummaryRepository(),
  evaluations: StubEvaluationRepository = StubEvaluationRepository(),
  profiles: StubProfileReader = StubProfileReader(),
  onEvaluationCompleted: @escaping @MainActor (EvaluationPeriod) -> Void = { _ in }
) -> EvaluationSummaryEditorViewModel {
  EvaluationSummaryEditorViewModel(
    student: CoachStudentSummary(
      id: BindQueueFixtures.studentID,
      displayName: "张三",
      status: .inEvaluation(remainingDays: 4, remainingHours: 13)
    ),
    evaluation: evaluation,
    summaries: summaries,
    evaluations: evaluations,
    profiles: profiles,
    onEvaluationCompleted: onEvaluationCompleted
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loadEntersFirstSaveModeWithoutExistingSummary() async {
  let editor = makeEditor(evaluation: BindQueueFixtures.evaluation())

  await editor.load()

  #expect(editor.state == .ready)
  #expect(!editor.isEditMode)
  #expect(editor.overallAssessment.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loadPrefillsEditModeFromExistingSummary() async {
  let existing = EvaluationSummary(
    id: UUID(),
    studentId: BindQueueFixtures.studentID,
    coachId: BindQueueFixtures.coachID,
    overallAssessment: "底力扎实",
    trainingPlan: "技术周期",
    wordsToStudent: "继续保持",
    firstSavedAt: BindQueueFixtures.now,
    lastUpdatedAt: BindQueueFixtures.now,
    isActive: true
  )
  let editor = makeEditor(
    evaluation: nil,
    summaries: StubEvaluationSummaryRepository(
      summariesByStudent: [BindQueueFixtures.studentID: existing])
  )

  await editor.load()

  #expect(editor.isEditMode)
  #expect(editor.overallAssessment == "底力扎实")
  #expect(editor.trainingPlanText == "技术周期")
  #expect(editor.wordsToStudent == "继续保持")
  // Edit-mode notify checkbox defaults off (D4).
  #expect(!editor.notifyOnSave)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func requiredFieldsGateSaving() async {
  let editor = makeEditor(evaluation: nil)
  await editor.load()

  editor.overallAssessment = "   "
  editor.trainingPlanText = "有内容"
  #expect(!editor.canSave)

  editor.overallAssessment = "有内容"
  #expect(editor.canSave)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func saveDraftNeverNotifiesInFirstSaveMode() async {
  let summaries = StubEvaluationSummaryRepository()
  let editor = makeEditor(evaluation: BindQueueFixtures.evaluation(), summaries: summaries)
  await editor.load()
  editor.overallAssessment = "底力扎实"
  editor.trainingPlanText = "技术周期"
  editor.wordsToStudent = "  "

  let saved = await editor.save()

  #expect(saved)
  let puts = await summaries.putRequests
  #expect(puts.count == 1)
  #expect(puts[0].notify == false)
  // Blank words are omitted, not sent empty (zod min(1)).
  #expect(puts[0].words == nil)
  #expect(!editor.showSoftRecommendation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func editModeSaveUsesNotifyCheckbox() async {
  let existing = EvaluationSummary(
    id: UUID(),
    studentId: BindQueueFixtures.studentID,
    coachId: BindQueueFixtures.coachID,
    overallAssessment: "旧评估",
    trainingPlan: "旧规划",
    wordsToStudent: nil,
    firstSavedAt: BindQueueFixtures.now,
    lastUpdatedAt: BindQueueFixtures.now,
    isActive: true
  )
  let summaries = StubEvaluationSummaryRepository(
    summariesByStudent: [BindQueueFixtures.studentID: existing])
  let editor = makeEditor(evaluation: nil, summaries: summaries)
  await editor.load()
  editor.notifyOnSave = true

  _ = await editor.save()

  let puts = await summaries.putRequests
  #expect(puts[0].notify == true)
  // Edit mode never triggers the soft recommendation.
  #expect(!editor.showSoftRecommendation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completionChainRunsPutThenCompleteThenSoftRecommendation() async {
  let evaluation = BindQueueFixtures.evaluation()
  let summaries = StubEvaluationSummaryRepository()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation])
  var reportedCompletion: EvaluationPeriod?
  let editor = makeEditor(
    evaluation: evaluation,
    summaries: summaries,
    evaluations: evaluations,
    onEvaluationCompleted: { reportedCompletion = $0 }
  )
  await editor.load()
  editor.overallAssessment = "底力扎实"
  editor.trainingPlanText = "技术周期"

  let finished = await editor.completeAndNotify()

  #expect(finished)
  let puts = await summaries.putRequests
  #expect(puts.count == 1)
  #expect(puts[0].notify == true)
  let completedIDs = await evaluations.completedIDs
  #expect(completedIDs == [evaluation.id])
  #expect(editor.showSoftRecommendation)
  #expect(reportedCompletion?.completedAt != nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completionChainIgnoresConcurrentCompleteConflict() async {
  let evaluation = BindQueueFixtures.evaluation()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation],
    completeError: EvaluationError.alreadyCompleted
  )
  let editor = makeEditor(
    evaluation: evaluation,
    evaluations: evaluations
  )
  await editor.load()
  editor.overallAssessment = "底力扎实"
  editor.trainingPlanText = "技术周期"

  let finished = await editor.completeAndNotify()

  // 409 reads as converged: the summary is in, recommendation still shows.
  #expect(finished)
  #expect(editor.showSoftRecommendation)
  #expect(editor.noticeMessage == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func completionChainDegradesWhenCompleteFailsButSummarySaved() async {
  let evaluation = BindQueueFixtures.evaluation()
  let summaries = StubEvaluationSummaryRepository()
  let evaluations = StubEvaluationRepository(
    evaluationsByStudent: [BindQueueFixtures.studentID: evaluation],
    completeError: CoachFeatureTestError()
  )
  let editor = makeEditor(
    evaluation: evaluation,
    summaries: summaries,
    evaluations: evaluations
  )
  await editor.load()
  editor.overallAssessment = "底力扎实"
  editor.trainingPlanText = "技术周期"

  let finished = await editor.completeAndNotify()

  // PUT-first (D3): summary persisted, completing failed → degrade banner,
  // no soft recommendation (publishing regular plans is still gated).
  #expect(!finished)
  let puts = await summaries.putRequests
  #expect(puts.count == 1)
  #expect(editor.noticeMessage == "总结已保存,但完成评估失败,请在学员详情页重试")
  #expect(!editor.showSoftRecommendation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func skipEvaluationStudentChainSkipsCompleteStep() async {
  let evaluations = StubEvaluationRepository()
  let editor = makeEditor(evaluation: nil, evaluations: evaluations)
  await editor.load()
  editor.overallAssessment = "底力扎实"
  editor.trainingPlanText = "技术周期"

  let finished = await editor.completeAndNotify()

  #expect(finished)
  let completedIDs = await evaluations.completedIDs
  #expect(completedIDs.isEmpty)
  #expect(editor.showSoftRecommendation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func prefillProfileMissReturnsNilWithNotice() async {
  let editor = makeEditor(
    evaluation: nil,
    profiles: StubProfileReader(profile: nil)
  )
  await editor.load()

  let profile = await editor.fetchPrefillProfile()

  #expect(profile == nil)
  #expect(editor.prefillNotice == "学员资料未读到,手动填写")
}
