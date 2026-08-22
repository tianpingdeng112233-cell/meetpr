import Analytics
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
  @Environment(\.scenePhase) private var scenePhase
  private let coachPlans: any PlanRepository
  private let coachInviteCodes: any InviteCodeRepository
  private let coachBindQueue: any CoachBindQueueRepository
  private let coachEvaluations: any EvaluationRepository
  private let coachEvaluationSummaries: any EvaluationSummaryRepository
  private let coachStudentProfiles: any OnboardingProfileReading
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let studentFeedback: any StudentFeedbackRepository
  private let videoMarkers: any VideoMarkerRepository
  private let studentE1RM: any E1RMRepository
  private let studentReadiness: any ReadinessRepository
  private let studentVideoUploads: VideoUploadServices?
  private let restTimerActivityController: any RestTimerActivityControlling
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
  private let coachExerciseStats: any CoachExerciseStatsProviding
  private let draftStore: DraftStore
  private let analyticsMode: AnalyticsMode
  let pushRegistrar: PushRegistrar?
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
    videoMarkers: (any VideoMarkerRepository)? = nil,
    studentE1RM: (any E1RMRepository)? = nil,
    studentReadiness: (any ReadinessRepository)? = nil,
    studentVideoUploads: VideoUploadServices? = nil,
    restTimerActivityController: (any RestTimerActivityControlling)? = nil,
    studentBind: (any BindRepository)? = nil,
    studentOnboarding: (any OnboardingRepository)? = nil,
    studentEvaluations: (any EvaluationRepository)? = nil,
    studentEvaluationSummaries: (any EvaluationSummaryRepository)? = nil,
    studentAccount: (any AccountRepository)? = nil,
    summaryReadStore: (any EvaluationSummaryReadStoring)? = nil,
    pendingBindStore: any PendingBindCodeStoring = UserDefaultsPendingBindCodeStore(),
    coachStudentVideos: (any CoachStudentVideoRepository)? = nil,
    coachVideoQueue: (any CoachVideoQueueRepository)? = nil,
    exerciseStats: (any CoachExerciseStatsProviding)? = nil,
    chatSession: ChatSessionController = ChatSessionController(),
    chatRepository: (any ChatRepository)? = nil,
    draftStore: DraftStore = DraftStore.shared,
    analyticsMode: AnalyticsMode = .disabled,
    pushRegistrar: PushRegistrar? = nil
  ) {
    self.coachPlans = coachPlans
    self.coachInviteCodes = coachInviteCodes ?? RootViewDemoDefaults.inviteCodes()
    self.studentPlans = studentPlans ?? RootViewDemoDefaults.plans()
    self.studentLogs = studentLogs ?? RootViewDemoDefaults.logs()
    self.studentFeedback = studentFeedback ?? RootViewDemoDefaults.feedback()
    self.videoMarkers = videoMarkers ?? InMemoryVideoMarkerRepository()
    self.studentE1RM = studentE1RM ?? RootViewDemoDefaults.e1rm()
    self.studentReadiness = studentReadiness ?? RootViewDemoDefaults.readiness()
    self.studentVideoUploads = studentVideoUploads
    self.restTimerActivityController =
      restTimerActivityController ?? NoOpRestTimerActivityController()
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
    self.coachExerciseStats = exerciseStats ?? RootViewDemoDefaults.exerciseStats()
    _chatSession = State(initialValue: chatSession)
    self.chatRepository = chatRepository
    self.draftStore = draftStore
    self.analyticsMode = analyticsMode
    self.pushRegistrar = pushRegistrar
    Analytics.shared.prepare(mode: analyticsMode)
  }
  public var body: some View {
    routedContent
      .analyticsFrictionFeedbackPrompt()
      .modifier(AnalyticsRootModifier(session: session, mode: analyticsMode))
      .onChange(of: scenePhase) { _, phase in
        // Intent is recorded synchronously; the controller serializes the
        // async application so rapid flips cannot land out of order.
        switch phase {
        case .active:
          chatSession.noteScenePhase(isActive: true)
          pushRegistrar?.applicationDidBecomeActive()
        case .background:
          chatSession.noteScenePhase(isActive: false)
        case .inactive:
          break
        @unknown default:
          break
        }
      }
      .onChange(of: session.state) { oldState, newState in
        guard Self.isAuthenticated(oldState), !Self.isAuthenticated(newState) else { return }
        pushRegistrar?.authenticatedSessionDidEnd()
      }
  }

  @ViewBuilder
  private var routedContent: some View {
    switch session.state {
    case .anonymous:
      AuthFlowView()
    case .authenticating:
      VStack(spacing: 12) {
        ProgressView()
        Text(AppShellStrings.validatingSession)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    case .authenticated(let user):
      authenticatedContent(for: user)
    }
  }

  @ViewBuilder
  private func authenticatedContent(for user: User) -> some View {
    Group {
      switch Self.authenticatedDestination(for: user.role) {
      case .coach:
        coachRoot(for: user)
      case .studentBehindE1RMGate:
        studentEntry(for: user)
      }
    }
    .onAppear {
      pushRegistrar?.authenticatedRootDidAppear()
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
        studentRoot(for: user, activeCoach: nil, chat: nil, allowsChat: false)
      }
    }
  }

  @ViewBuilder
  private func coachRoot(for user: User) -> some View {
    if let chatRepository {
      // A student context carries a bound coach; the coach root must never
      // inherit one, so require the neutral (nil) binding as well as the user.
      if let chat = chatSession.context, chat.currentUserID == user.id,
        chatSession.activeStudentCoachID == nil
      {
        coachContent(for: user, chat: chat)
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
      coachContent(for: user, chat: nil)
    }
  }

  private func coachContent(for user: User, chat: ChatSessionContext?) -> some View {
    CoachRootView(
      repository: coachPlans,
      studentPlans: studentPlans,
      studentLogs: studentLogs,
      feedback: studentFeedback,
      videoMarkers: videoMarkers,
      inviteCodes: coachInviteCodes,
      studentVideos: coachStudentVideos,
      readiness: studentReadiness,
      exerciseStats: coachExerciseStats,
      bindQueue: coachBindQueue,
      evaluations: coachEvaluations,
      evaluationSummaries: coachEvaluationSummaries,
      studentProfiles: coachStudentProfiles,
      videoQueue: coachVideoQueue,
      chat: chat?.repository,
      currentUserID: chat?.currentUserID,
      inbox: chat?.inbox,
      sendCoordinator: chat?.sendCoordinator,
      coachDisplayName: user.name,
      privacyPolicyURL: AnalyticsPrivacyNotice.privacyPolicyURL,
      onLogout: {
        await session.logout()
      },
      draftStore: draftStore,
      pushRoute: pushRouteBinding
    )
  }

}

extension RootView {
  // swiftlint:disable:next function_body_length
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
      willApplyBindingChange: { oldCoachID, newCoachID in
        await chatSession.prepareForStudentBindingChange(
          from: oldCoachID,
          to: newCoachID
        )
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
      content: { activeCoach, refreshBinding in
        studentChatRoot(
          for: user,
          activeCoach: activeCoach,
          refreshBinding: refreshBinding
        )
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

  @ViewBuilder
  private func studentChatRoot(
    for user: User,
    activeCoach: ActiveCoachContext,
    refreshBinding: @escaping @MainActor @Sendable () async -> Void
  ) -> some View {
    if let chatRepository {
      // Match the coach too: after a switch, a context built for the previous
      // coach still has the right user id and would otherwise be handed to the
      // new coach's UI.
      if let chat = chatSession.context, chat.currentUserID == user.id,
        chatSession.activeStudentCoachID == activeCoach.coachID
      {
        studentRoot(for: user, activeCoach: activeCoach, chat: chat, allowsChat: true)
      } else if chatSession.canActivateStudent(for: activeCoach.coachID) {
        ProgressView()
          .task(id: activeCoach.coachID) {
            await chatSession.activateStudent(
              repository: chatRepository,
              currentUserID: user.id,
              activeCoachID: activeCoach.coachID,
              refreshBinding: refreshBinding
            )
          }
      } else {
        ProgressView()
      }
    } else {
      studentRoot(for: user, activeCoach: activeCoach, chat: nil, allowsChat: true)
    }
  }

  private func studentRoot(
    for user: User,
    activeCoach: ActiveCoachContext?,
    chat: ChatSessionContext?,
    allowsChat: Bool
  ) -> some View {
    StudentRootView(
      studentID: user.id,
      plans: studentPlans,
      logs: studentLogs,
      feedback: studentFeedback,
      videoMarkers: videoMarkers,
      e1rm: studentE1RM,
      readiness: studentReadiness,
      videoUploads: studentVideoUploads,
      onboarding: studentOnboarding,
      evaluationSummaries: studentEvaluationSummaries,
      summaryReadStore: summaryReadStore,
      onLogout: {
        await session.logout()
      },
      account: studentAccount,
      restTimerActivityController: restTimerActivityController,
      allowsChat: allowsChat,
      chat: chat?.repository,
      currentUserID: chat?.currentUserID,
      inbox: chat?.inbox,
      sendCoordinator: chat?.sendCoordinator,
      activeCoach: activeCoach,
      onBindingInvalidated: {
        await chatSession.reportBindingInvalidation()
      },
      pushRoute: pushRouteBinding
    )
  }
}
