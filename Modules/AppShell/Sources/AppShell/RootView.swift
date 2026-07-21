import Analytics
import CatalogKit
import ChatUI
import CoachKit
import CoreModels
import Foundation
import RepositoryContracts
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct RootView: View {
  enum AuthenticatedDestination: Equatable {
    case coach
    case studentBehindE1RMGate
  }

  @Environment(Session.self) private var session
  private let coachPlans: any PlanRepository
  private let coachInviteCodes: any InviteCodeRepository
  private let coachBindQueue: any CoachBindQueueRepository
  private let coachEvaluations: any EvaluationRepository
  private let coachEvaluationSummaries: any EvaluationSummaryRepository
  private let coachStudentProfiles: any OnboardingProfileReading
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let studentFeedback: any StudentFeedbackRepository
  private let studentE1RM: any E1RMRepository
  private let studentReadiness: any ReadinessRepository
  private let studentVideoUploads: VideoUploadServices?
  private let studentBind: any BindRepository
  private let studentOnboarding: any OnboardingRepository
  private let studentEvaluations: any EvaluationRepository
  private let studentEvaluationSummaries: any EvaluationSummaryRepository
  private let studentAccount: any AccountRepository
  private let summaryReadStore: any EvaluationSummaryReadStoring
  private let pendingBindStore: any PendingBindCodeStoring
  private let onboardingDraftStore = LocalOnboardingDraftStore()
  private let coachStudentVideos: any CoachStudentVideoRepository
  private let coachVideoQueue: (any CoachVideoQueueRepository)?
  private let coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)?
  private let draftStore: DraftStore
  private let analyticsMode: AnalyticsMode
  @State private var chatSession: ChatSessionController
  private let chatRepository: (any ChatRepository)?

  public init(
    coachPlans: any PlanRepository = InMemoryPlanRepository.preview(),
    coachInviteCodes: (any InviteCodeRepository)? = nil,
    coachBindQueue: (any CoachBindQueueRepository)? = nil,
    coachEvaluations: (any EvaluationRepository)? = nil,
    coachEvaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    coachStudentProfiles: (any OnboardingProfileReading)? = nil,
    studentPlans: (any StudentPlanRepository)? = nil,
    studentLogs: (any StudentTrainingLogRepository)? = nil,
    studentFeedback: (any StudentFeedbackRepository)? = nil,
    studentE1RM: (any E1RMRepository)? = nil,
    studentReadiness: (any ReadinessRepository)? = nil,
    studentVideoUploads: VideoUploadServices? = nil,
    studentBind: (any BindRepository)? = nil,
    studentOnboarding: (any OnboardingRepository)? = nil,
    studentEvaluations: (any EvaluationRepository)? = nil,
    studentEvaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    studentAccount: (any AccountRepository)? = nil,
    summaryReadStore: (any EvaluationSummaryReadStoring)? = nil,
    pendingBindStore: any PendingBindCodeStoring = UserDefaultsPendingBindCodeStore(),
    coachStudentVideos: (any CoachStudentVideoRepository)? = nil,
    coachVideoQueue: (any CoachVideoQueueRepository)? = nil,
    coachFamilyMapProvider: (any CoachPlanFamilyMapProviding)? = nil,
    chatSession: ChatSessionController = ChatSessionController(),
    chatRepository: (any ChatRepository)? = nil,
    draftStore: DraftStore = DraftStore.shared,
    analyticsMode: AnalyticsMode = .disabled
  ) {
    self.coachPlans = coachPlans
    self.coachInviteCodes = coachInviteCodes ?? RootViewDemoDefaults.inviteCodes()
    self.studentPlans = studentPlans ?? RootViewDemoDefaults.plans()
    self.studentLogs = studentLogs ?? RootViewDemoDefaults.logs()
    self.studentFeedback = studentFeedback ?? RootViewDemoDefaults.feedback()
    self.studentE1RM = studentE1RM ?? RootViewDemoDefaults.e1rm()
    self.studentReadiness = studentReadiness ?? RootViewDemoDefaults.readiness()
    self.studentVideoUploads = studentVideoUploads
    self.studentBind = studentBind ?? RootViewDemoDefaults.bind()
    self.studentOnboarding = studentOnboarding ?? RootViewDemoDefaults.onboarding()
    // Evaluation funnel defaults (spec 033): in-memory demo/preview repos;
    // the live wiring injects the Backend implementations from MeetPRApp.
    self.coachBindQueue =
      coachBindQueue
      ?? InMemoryCoachBindQueueRepository(coachId: StudentDemoSeed.coachID)
    self.coachEvaluations = coachEvaluations ?? InMemoryCoachEvaluationRepository()
    self.coachEvaluationSummaries =
      coachEvaluationSummaries
      ?? InMemoryCoachEvaluationSummaryRepository(coachId: StudentDemoSeed.coachID)
    self.coachStudentProfiles =
      coachStudentProfiles ?? RootViewDemoDefaults.coachStudentProfiles()
    self.studentEvaluations = studentEvaluations ?? InMemoryStudentEvaluationRepository()
    self.studentEvaluationSummaries =
      studentEvaluationSummaries ?? InMemoryEvaluationSummaryRepository()
    self.studentAccount = studentAccount ?? InMemoryAccountRepository()
    self.summaryReadStore = summaryReadStore ?? UserDefaultsEvaluationSummaryReadStore()
    self.pendingBindStore = pendingBindStore
    self.coachStudentVideos = coachStudentVideos ?? InMemoryCoachStudentVideoRepository()
    self.coachVideoQueue = coachVideoQueue
    self.coachFamilyMapProvider = coachFamilyMapProvider
    _chatSession = State(initialValue: chatSession)
    self.chatRepository = chatRepository
    self.draftStore = draftStore
    self.analyticsMode = analyticsMode
    Analytics.shared.prepare(mode: analyticsMode)
  }

  public var body: some View {
    routedContent
      .analyticsFrictionFeedbackPrompt()
      .modifier(AnalyticsRootModifier(session: session, mode: analyticsMode))
  }

  @ViewBuilder
  private var routedContent: some View {
    switch session.state {
    case .anonymous:
      AuthFlowView()
    case .authenticating:
      VStack(spacing: 12) {
        ProgressView()
        Text("正在验证会话…")
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    case .authenticated(let user):
      authenticatedContent(for: user)
    }
  }

  @ViewBuilder
  private func authenticatedContent(for user: User) -> some View {
    switch Self.authenticatedDestination(for: user.role) {
    case .coach:
      coachRoot(for: user)
    case .studentBehindE1RMGate:
      studentEntry(for: user)
    }
  }

  static func authenticatedDestination(for role: UserRole) -> AuthenticatedDestination {
    switch role {
    case .coach: .coach
    case .coachedStudent, .selfTrainStudent: .studentBehindE1RMGate
    }
  }

  private func studentEntry(for user: User) -> some View {
    E1RMCompetitionLiftGate(
      studentID: user.id,
      plans: studentPlans,
      logs: studentLogs,
      onboarding: studentOnboarding,
      e1rm: studentE1RM
    ) {
      if user.role == .coachedStudent {
        // EvaluationPeriodView and the bound five-tab root both live below
        // the same migration gate, so neither can consume stale e1RM history.
        bindGatedStudentRoot(for: user)
      } else {
        studentRoot(for: user)
      }
    }
  }

  @ViewBuilder
  private func coachRoot(for user: User) -> some View {
    if let chatRepository {
      if let chat = chatSession.context, chat.currentUserID == user.id {
        coachContent(chat: chat)
      } else {
        ProgressView()
          .task(id: user.id) {
            await chatSession.activateCoach(
              repository: chatRepository,
              currentUserID: user.id
            )
          }
      }
    } else {
      coachContent(chat: nil)
    }
  }

  private func coachContent(chat: ChatSessionContext?) -> some View {
    CoachRootView(
      repository: coachPlans,
      studentPlans: studentPlans,
      studentLogs: studentLogs,
      feedback: studentFeedback,
      inviteCodes: coachInviteCodes,
      studentVideos: coachStudentVideos,
      readiness: studentReadiness,
      familyMapProvider: coachFamilyMapProvider,
      bindQueue: coachBindQueue,
      evaluations: coachEvaluations,
      evaluationSummaries: coachEvaluationSummaries,
      studentProfiles: coachStudentProfiles,
      videoQueue: coachVideoQueue,
      chat: chat?.repository,
      currentUserID: chat?.currentUserID,
      inbox: chat?.inbox,
      sendCoordinator: chat?.sendCoordinator,
      onLogout: {
        await session.logout()
      },
      draftStore: draftStore
    )
  }

  private func bindGatedStudentRoot(for user: User) -> some View {
    let onboarding = studentOnboarding
    let studentId = user.id
    return BindGateView(
      studentId: studentId,
      bind: studentBind,
      stash: pendingBindStore,
      evaluations: studentEvaluations,
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
      // Pre-bind pages live outside the 5 tabs — without this the account
      // has no way back to the login screen.
      onLogout: {
        await session.logout()
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
      evaluationFlow: { _, onCompleted in
        // Single-page evaluation state replaces the 5 tabs (spec 033 D6).
        EvaluationPeriodView(
          studentID: studentId,
          dependencies: evaluationPeriodDependencies,
          onLogout: {
            await session.logout()
          },
          onCompleted: onCompleted
        )
      },
      content: {
        studentRoot(for: user)
      }
    )
  }

  private var evaluationPeriodDependencies: EvaluationPeriodDependencies {
    EvaluationPeriodDependencies(
      evaluations: studentEvaluations,
      plans: studentPlans,
      logs: studentLogs,
      feedback: studentFeedback,
      e1rm: studentE1RM,
      readiness: studentReadiness,
      onboarding: studentOnboarding
    )
  }

  private func studentRoot(for user: User) -> some View {
    StudentRootView(
      studentID: user.id,
      canShiftPlanDays: user.role == .coachedStudent,
      plans: studentPlans,
      logs: studentLogs,
      feedback: studentFeedback,
      e1rm: studentE1RM,
      readiness: studentReadiness,
      videoUploads: studentVideoUploads,
      onboarding: studentOnboarding,
      evaluationSummaries: studentEvaluationSummaries,
      summaryReadStore: summaryReadStore,
      onLogout: {
        await session.logout()
      },
      account: studentAccount
    )
  }
}

/// Demo/preview fallbacks for RootView's injection points. An accepted bond
/// plus a completed profile keep the existing student demo flow untouched —
/// the BindGate falls straight through to the 5 tabs (spec 031 D10).
@available(iOS 17.0, macOS 14.0, *)
private enum RootViewDemoDefaults {
  static func inviteCodes() -> any InviteCodeRepository {
    InMemoryInviteCodeRepository(
      coachId: StudentDemoSeed.coachID,
      seed: InMemoryInviteCodeRepository.demoSeed(coachId: StudentDemoSeed.coachID)
    )
  }

  static func plans() -> any StudentPlanRepository {
    let plan = StudentDemoSeed.makePlanView()
    let store = InMemoryPlanStore()
    Task {
      await store.savePublishedProjection(plan, forStudent: StudentDemoSeed.studentID)
    }
    return InMemoryStudentPlanRepository(store: store)
  }

  static func logs() -> any StudentTrainingLogRepository {
    InMemoryStudentTrainingLogRepository(
      seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
    )
  }

  static func feedback() -> any StudentFeedbackRepository {
    InMemoryStudentFeedbackRepository(
      seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
    )
  }

  static func e1rm() -> any E1RMRepository {
    InMemoryE1RMRepository(
      seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID),
      seedPRs: StudentDemoSeed.makeUnacknowledgedPR(studentID: StudentDemoSeed.studentID)
    )
  }

  static func readiness() -> any ReadinessRepository {
    InMemoryReadinessRepository(
      seed: StudentDemoSeed.makeReadinessHistory(studentID: StudentDemoSeed.studentID)
    )
  }

  static func bind() -> any BindRepository {
    InMemoryBindRepository(
      studentId: StudentDemoSeed.studentID,
      seed: StudentDemoSeed.makeAcceptedBindRequest(studentID: StudentDemoSeed.studentID)
    )
  }

  static func onboarding() -> any OnboardingRepository {
    InMemoryOnboardingRepository(
      studentId: StudentDemoSeed.studentID,
      seed: StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
    )
  }

  static func coachStudentProfiles() -> any OnboardingProfileReading {
    InMemoryCoachStudentProfileReader(
      profiles: [StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)]
    )
  }
}
