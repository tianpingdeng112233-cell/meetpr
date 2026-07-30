import CoreModels
import Foundation
import Testing
import ViewInspector

@testable import CoachKit

@Test func coachEvaluationSealKeepsEvaluationBannerAndLoadingDormant() {
  #expect(CoachEvaluationSeal.isSealed)
  #expect(!CoachEvaluationSeal.shouldRenderBanner(isBannerVisible: true))
  #expect(!CoachEvaluationSeal.shouldRenderBanner(isBannerVisible: false))
  #expect(!CoachEvaluationSeal.shouldLoadEvaluation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func sealedStudentDetailDoesNotRenderEvaluationBanner() throws {
  let student = CoachStudentSummary(
    id: UUID(),
    displayName: "王晨曦",
    status: .active
  )
  let context = CoachStudentDetailContext(
    plans: EmptyStudentPlanRepository(),
    trainingLogs: EmptyStudentTrainingLogRepository(),
    feedback: EmptyStudentFeedbackRepository(),
    evaluations: InMemoryCoachEvaluationRepository(),
    summaries: InMemoryCoachEvaluationSummaryRepository(coachId: UUID()),
    profiles: InMemoryCoachStudentProfileReader(),
    videos: InMemoryCoachStudentVideoRepository(),
    readiness: EmptyReadinessRepository(),
    familyMapProvider: nil,
    planning: InMemoryPlanRepository(students: [], catalog: []),
    draftStore: try DraftStore.inMemory()
  )

  let banners = try StudentDetailView(summary: student, context: context)
    .inspect()
    .findAll(EvaluationStatusBanner.self)

  #expect(banners.isEmpty)
}
