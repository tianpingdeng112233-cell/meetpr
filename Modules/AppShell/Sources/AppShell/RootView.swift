import CoachKit
import CoreModels
import RepositoryContracts
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {
  @Environment(Session.self) private var session
  private let coachPlans: any PlanRepository
  private let coachInviteCodes: any InviteCodeRepository
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let studentFeedback: any StudentFeedbackRepository
  private let studentE1RM: any E1RMRepository
  private let studentReadiness: any ReadinessRepository
  private let studentVideoUploads: VideoUploadServices?
  private let studentBind: any BindRepository
  private let studentOnboarding: any OnboardingRepository
  private let pendingBindStore: any PendingBindCodeStoring
  private let onboardingDraftStore = LocalOnboardingDraftStore()
  private let coachStudentVideos: any CoachStudentVideoRepository
  private let coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)?
  private let draftStore: DraftStore

  public init(
    coachPlans: any PlanRepository = InMemoryPlanRepository.preview(),
    coachInviteCodes: (any InviteCodeRepository)? = nil,
    studentPlans: (any StudentPlanRepository)? = nil,
    studentLogs: (any StudentTrainingLogRepository)? = nil,
    studentFeedback: (any StudentFeedbackRepository)? = nil,
    studentE1RM: (any E1RMRepository)? = nil,
    studentReadiness: (any ReadinessRepository)? = nil,
    studentVideoUploads: VideoUploadServices? = nil,
    studentBind: (any BindRepository)? = nil,
    studentOnboarding: (any OnboardingRepository)? = nil,
    pendingBindStore: any PendingBindCodeStoring = UserDefaultsPendingBindCodeStore(),
    coachStudentVideos: (any CoachStudentVideoRepository)? = nil,
    coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)? = nil,
    draftStore: DraftStore = DraftStore.shared
  ) {
    let plan = StudentDemoSeed.makePlanView()
    let store = InMemoryPlanStore()
    Task {
      await store.savePublishedProjection(plan, forStudent: StudentDemoSeed.studentID)
    }
    self.coachPlans = coachPlans
    self.coachInviteCodes =
      coachInviteCodes
      ?? InMemoryInviteCodeRepository(
        coachId: StudentDemoSeed.coachID,
        seed: InMemoryInviteCodeRepository.demoSeed(coachId: StudentDemoSeed.coachID)
      )
    self.studentPlans = studentPlans ?? InMemoryStudentPlanRepository(store: store)
    self.studentLogs =
      studentLogs
      ?? InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
      )
    self.studentFeedback =
      studentFeedback
      ?? InMemoryStudentFeedbackRepository(
        seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
      )
    self.studentE1RM =
      studentE1RM
      ?? InMemoryE1RMRepository(
        seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
        seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
      )
    self.studentReadiness =
      studentReadiness
      ?? InMemoryReadinessRepository(
        seed: StudentDemoSeed.makeReadinessHistory(studentID: StudentDemoSeed.studentID)
      )
    self.studentVideoUploads = studentVideoUploads
    // Demo defaults keep the existing student demo flow untouched: an
    // accepted bond + a completed profile mean the BindGate falls straight
    // through to the 5 tabs (spec 031 D10).
    self.studentBind =
      studentBind
      ?? InMemoryBindRepository(
        studentId: StudentDemoSeed.studentID,
        seed: StudentDemoSeed.makeAcceptedBindRequest(studentID: StudentDemoSeed.studentID)
      )
    self.studentOnboarding =
      studentOnboarding
      ?? InMemoryOnboardingRepository(
        studentId: StudentDemoSeed.studentID,
        seed: StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
      )
    self.pendingBindStore = pendingBindStore
    // Demo/preview default: an empty wall — the coach video grid renders its
    // empty state without a backend.
    self.coachStudentVideos = coachStudentVideos ?? InMemoryCoachStudentVideoRepository()
    self.coachFamilyMapProvider = coachFamilyMapProvider
    self.draftStore = draftStore
  }

  public var body: some View {
    switch session.state {
    case .anonymous, .authenticating:
      AuthFlowView()
    case .authenticated(let user):
      switch user.role {
      case .coach:
        CoachRootView(
          repository: coachPlans,
          studentPlans: studentPlans,
          studentLogs: studentLogs,
          feedback: studentFeedback,
          inviteCodes: coachInviteCodes,
          studentVideos: coachStudentVideos,
          readiness: studentReadiness,
          familyMapProvider: coachFamilyMapProvider,
          onLogout: {
            await session.logout()
          },
          draftStore: draftStore
        )
      case .coachedStudent:
        // BindGate wraps coached students only (spec 031 D4); the wizard
        // slot + completion-probe closures are 032's real implementations.
        bindGatedStudentRoot(for: user)
      case .selfTrainStudent:
        // Self-train students never bind (backend requireRole gate) and
        // skip the BindGate entirely (spec 031 D4).
        studentRoot(for: user)
      }
    }
  }

  private func bindGatedStudentRoot(for user: User) -> some View {
    let onboarding = studentOnboarding
    let studentId = user.id
    return BindGateView(
      studentId: studentId,
      bind: studentBind,
      stash: pendingBindStore,
      isOnboardingComplete: {
        // Fetch failure reads as "incomplete" (`try?` flattens the error and
        // the 404 into nil): worst case is one extra trip through the wizard
        // resume, which is harmless (spec 032 contract).
        guard let profile = try? await onboarding.fetchProfile(studentId: studentId) else {
          return false
        }
        return profile.isCompleted
      },
      onboardingProfile: {
        try? await onboarding.fetchProfile(studentId: studentId)
      },
      onboardingFlow: { _, onCompleted in
        OnboardingWizardFlow(
          studentId: studentId,
          repo: onboarding,
          draftStore: onboardingDraftStore,
          bind: studentBind,
          stash: pendingBindStore,
          onCompleted: onCompleted
        )
      },
      content: {
        studentRoot(for: user)
      }
    )
  }

  private func studentRoot(for user: User) -> some View {
    StudentRootView(
      studentID: user.id,
      plans: studentPlans,
      logs: studentLogs,
      feedback: studentFeedback,
      e1rm: studentE1RM,
      readiness: studentReadiness,
      videoUploads: studentVideoUploads,
      onboarding: studentOnboarding
    )
  }
}
