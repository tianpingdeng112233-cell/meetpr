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
  let exerciseStats: any CoachExerciseStatsProviding
  /// Planning entry (适应周 / 软推荐立即排) dependencies.
  let planning: any PlanRepository
  let draftStore: DraftStore
  let chat: CoachChatContext?

  init(
    plans: any StudentPlanRepository,
    trainingLogs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    evaluations: any EvaluationRepository,
    summaries: any EvaluationSummaryRepository,
    profiles: any OnboardingProfileReading,
    videos: any CoachStudentVideoRepository,
    readiness: any ReadinessRepository,
    exerciseStats: any CoachExerciseStatsProviding,
    planning: any PlanRepository,
    draftStore: DraftStore,
    chat: CoachChatContext? = nil
  ) {
    self.plans = plans
    self.trainingLogs = trainingLogs
    self.feedback = feedback
    self.evaluations = evaluations
    self.summaries = summaries
    self.profiles = profiles
    self.videos = videos
    self.readiness = readiness
    self.exerciseStats = exerciseStats
    self.planning = planning
    self.draftStore = draftStore
    self.chat = chat
  }
}
