import Foundation
import RepositoryContracts

/// Repository bundle threaded CoachRootView → StudentRosterView →
/// StudentDetailView (spec 033). Keeps view initializers stable while the
/// evaluation funnel adds read/write surfaces.
@MainActor
struct CoachStudentDetailContext {
  let plans: any StudentPlanRepository
  let trainingLogs: any StudentTrainingLogRepository
  let feedback: any StudentFeedbackRepository
  let evaluations: any EvaluationRepository
  let summaries: any EvaluationSummaryRepository
  let profiles: any OnboardingProfileReading
  /// Video wall + readiness row + growth mapping (spec 029 second pass).
  let videos: any CoachStudentVideoRepository
  let readiness: any ReadinessRepository
  let familyMapProvider: (any CoachPlanFamilyMapProviding)?
  /// Planning entry (适应周 / 软推荐立即排) dependencies.
  let planning: any PlanRepository
  let draftStore: DraftStore
}
