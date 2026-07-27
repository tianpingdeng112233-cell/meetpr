import AppShell
import ChatUI
import CoachKit
import CoreModels
import Networking
import StudentKit
import SwiftData
import SwiftUI

@main
@MainActor
struct MeetPRApp: App {
  private let draftStore: DraftStore
  private let rootView: RootView
  @State private var session: Session

  init() {
    let draftStore = DraftStore.shared
    self.draftStore = draftStore

    let dependencies = Self.makeRootDependencies(draftStore: draftStore)
    rootView = dependencies.rootView
    _session = State(initialValue: dependencies.session)
  }

  private struct RootDependencies {
    let rootView: RootView
    let session: Session
  }

  #if DEMO_MODE
    private struct DemoEvaluationFunnel {
      let bindQueue: InMemoryCoachBindQueueRepository
      let evaluations: InMemoryCoachEvaluationRepository
      let summaries: InMemoryCoachEvaluationSummaryRepository
      let profiles: InMemoryCoachStudentProfileReader
    }

    private struct DemoChatDependencies {
      let session: Session
      let controller: ChatSessionController
      let repository: InMemoryChatRepository
    }

    /// Demo evaluation funnel (spec 033): one pending receive-queue card +
    /// live evaluation periods for the two in-evaluation roster students.
    /// Queue accepts mint periods into the same shared store.
    private static func makeDemoEvaluationFunnel() -> DemoEvaluationFunnel {
      let evaluationStore = InMemoryEvaluationPeriodStore(
        seed: CoachDemoSeed.evaluationPeriods(coachId: StudentDemoSeed.coachID)
      )
      return DemoEvaluationFunnel(
        bindQueue: InMemoryCoachBindQueueRepository(
          coachId: StudentDemoSeed.coachID,
          seed: CoachDemoSeed.pendingBindRequests(),
          evaluationStore: evaluationStore
        ),
        evaluations: InMemoryCoachEvaluationRepository(store: evaluationStore),
        summaries: InMemoryCoachEvaluationSummaryRepository(coachId: StudentDemoSeed.coachID),
        profiles: InMemoryCoachStudentProfileReader(
          profiles: [
            StudentDemoSeed.makeOnboardingProfile(studentID: CoachDemoSeed.queueStudentID)
          ]
        )
      )
    }

    private static func makeDemoStudentLogs(
      includeToday: Bool
    ) -> InMemoryStudentTrainingLogRepository {
      InMemoryStudentTrainingLogRepository(
        seed: StudentDemoSeed.makeHistoricalLogs(
          studentID: StudentDemoSeed.studentID,
          includeToday: includeToday
        )
      )
    }

    private static func makeDemoChatDependencies(
      user: User,
      draftStore: DraftStore
    ) -> DemoChatDependencies {
      let controller = ChatSessionController()
      let session = Session(
        auth: DemoAuthRepository(user: user),
        tokenStore: DemoTokenStore(user: user),
        onLogout: {
          await controller.cancelAllAndWaitForCleanup()
          try? await draftStore.deleteAll()
        }
      )
      return DemoChatDependencies(
        session: session,
        controller: controller,
        repository: InMemoryChatRepository(
          currentUserID: user.id,
          seed: DemoChatSeed.make(for: user)
        )
      )
    }

    private static func makeRootDependencies(draftStore: DraftStore) -> RootDependencies {
      // Seed the student projection so the demo shows a real plan (today/week)
      // without a coach publish round-trip.
      let planStore = InMemoryPlanStore(
        seed: [StudentDemoSeed.studentID: StudentDemoSeed.makePlanView()])
      // DEMO_USER_STUDENT is read here in the app target, NOT inside AppShell:
      // Xcode does not propagate the app target's compilation conditions to its
      // SPM package deps, so the chosen user must be injected down.
      #if DEMO_USER_STUDENT
        let demoUser = DemoUserSeed.coachedStudent
      #else
        let demoUser = DemoUserSeed.coach
      #endif
      let chat = makeDemoChatDependencies(user: demoUser, draftStore: draftStore)
      let funnel = makeDemoEvaluationFunnel()
      return RootDependencies(
        rootView: RootView(
          coachPlans: InMemoryPlanRepository.preview(store: planStore),
          // Demo coach: personal (used 23) + unused single-use + 6-day
          // time-limited seed codes (spec 031 D10).
          coachInviteCodes: InMemoryInviteCodeRepository(
            coachId: StudentDemoSeed.coachID,
            seed: InMemoryInviteCodeRepository.demoSeed(coachId: StudentDemoSeed.coachID)
          ),
          coachBindQueue: funnel.bindQueue,
          coachEvaluations: funnel.evaluations,
          coachEvaluationSummaries: funnel.summaries,
          coachStudentProfiles: funnel.profiles,
          studentPlans: InMemoryStudentPlanRepository(store: planStore),
          studentLogs: makeDemoStudentLogs(includeToday: demoUser.role != .coachedStudent),
          studentFeedback: InMemoryStudentFeedbackRepository(
            seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
          ),
          // Demo student: accepted bond + completed profile → the BindGate
          // falls straight through to the 5 tabs; no wizard, no enter-code
          // (spec 031 D10 — the DEMO_USER_STUDENT path stays gate-free).
          studentBind: InMemoryBindRepository(
            studentId: StudentDemoSeed.studentID,
            seed: StudentDemoSeed.makeAcceptedBindRequest(studentID: StudentDemoSeed.studentID)
          ),
          studentOnboarding: InMemoryOnboardingRepository(
            studentId: StudentDemoSeed.studentID,
            seed: StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
          ),
          // 训练视频 inbox: boot straight into a populated queue (spec 042).
          coachVideoQueue: InMemoryCoachVideoQueueRepository(
            seed: CoachDemoSeed.pendingVideos()),
          chatSession: chat.controller,
          chatRepository: chat.repository,
          draftStore: draftStore,
          analyticsMode: .disabled
        ),
        session: chat.session
      )
    }
  #else
    private struct LiveChatDependencies {
      let session: Session
      let controller: ChatSessionController
      let repository: NetworkChatRepository
    }

    private static func makeSession(
      api: APIClient,
      draftStore: DraftStore,
      chatSession: ChatSessionController
    ) -> Session {
      let auth: any AuthRepository = NetworkingAuthRepository(api: api)
      let tokenStore: any TokenStoring = KeychainTokenStore()
      let session = Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: {
          await chatSession.cancelAllAndWaitForCleanup()
          try? await draftStore.deleteAll()
        }
      )
      api.bindUnauthorizedRecovery { [weak session] rejectedAccessToken in
        guard let session else {
          throw SessionStateReaderError.missingAccessToken
        }
        return try await session.recoverAccessToken(rejectedAccessToken: rejectedAccessToken)
      }
      session.bindToErrors(api.errorStream)
      return session
    }

    private static func makeLiveChatDependencies(
      api: APIClient,
      draftStore: DraftStore
    ) -> LiveChatDependencies {
      let controller = ChatSessionController()
      let session = makeSession(
        api: api,
        draftStore: draftStore,
        chatSession: controller
      )
      return LiveChatDependencies(
        session: session,
        controller: controller,
        repository: NetworkChatRepository(
          apiClient: api,
          session: session,
          uploader: OSSPartUploader()
        )
      )
    }

    private static func makeRootDependencies(draftStore: DraftStore) -> RootDependencies {
      let api = APIClient.shared
      let chat = makeLiveChatDependencies(api: api, draftStore: draftStore)
      return RootDependencies(
        rootView: RootView(
          coachPlans: BackendPlanRepository(
            api: api, session: chat.session, cache: PlanCache()),
          coachInviteCodes: BackendInviteCodeRepository(api: api, session: chat.session),
          // Coach receive queue + evaluation funnel (spec 033).
          coachBindQueue: BackendCoachBindQueueRepository(api: api, session: chat.session),
          coachEvaluations: BackendCoachEvaluationRepository(api: api, session: chat.session),
          coachEvaluationSummaries: BackendCoachEvaluationSummaryRepository(
            api: api, session: chat.session),
          coachStudentProfiles: BackendCoachStudentProfileReader(api: api, session: chat.session),
          studentPlans: BackendStudentPlanRepository(
            api: api,
            session: chat.session,
            cache: StudentPlanCache()
          ),
          studentLogs: BackendStudentTrainingLogRepository(
            api: api,
            session: chat.session,
            cache: TrainingLogCache()
          ),
          studentFeedback: BackendStudentFeedbackRepository(
            api: api,
            session: chat.session,
            cache: FeedbackCache()
          ),
          // e1RM stays fully on-device in V0.1 (spec 028 persistence ladder):
          // JSON files under Documents/e1rm/, no backend endpoint.
          studentE1RM: LocalE1RMRepository(),
          studentReadiness: BackendReadinessRepository(api: api, session: chat.session),
          // Set-video uploads (spec 027): backend /uploads/* pipeline; the
          // setLog ↔ attachment mapping persists on-device only in V0.1.
          studentVideoUploads: .backend(api: api, session: chat.session),
          // Bind + onboarding are cache-free by design (spec 031/032 §9):
          // both must read live server state.
          studentBind: BackendBindRepository(api: api, session: chat.session),
          studentOnboarding: BackendOnboardingRepository(api: api, session: chat.session),
          // Evaluation funnel (spec 033) — all cache-free by design.
          studentEvaluations: BackendStudentEvaluationRepository(api: api, session: chat.session),
          studentEvaluationSummaries: BackendEvaluationSummaryRepository(
            api: api, session: chat.session),
          studentAccount: BackendAccountRepository(api: api, session: chat.session),
          summaryReadStore: UserDefaultsEvaluationSummaryReadStore(),
          // Coach-side video wall (spec 029 second pass): server-side
          // metadata + per-item presigned playback URLs.
          coachStudentVideos: BackendCoachStudentVideoRepository(api: api, session: chat.session),
          // Growth-tab family mapping reads the coach-owned full plan tree
          // (the student projection only carries the current week).
          coachFamilyMapProvider: BackendCoachPlanFamilyMapProvider(
            api: api, session: chat.session),
          chatSession: chat.controller,
          chatRepository: chat.repository,
          draftStore: draftStore,
          analyticsMode: .live
        ),
        session: chat.session
      )
    }
  #endif

  private var preferredAppColorScheme: ColorScheme? {
    guard case .authenticated(let user) = session.state else {
      // Auth/login and bootstrap keep the v2 dark-only contract.
      return .dark
    }
    switch user.role {
    case .coach:
      // CoachKit has no audited light palette yet.
      return .dark
    case .coachedStudent, .selfTrainStudent:
      // Black-gold v3 student roots follow the device appearance.
      return nil
    }
  }

  var body: some Scene {
    WindowGroup {
      rootView
        .environment(session)
        .task {
          await session.bootstrap()
        }
        .modelContainer(
          draftStore.modelContainer
        )
        .preferredColorScheme(preferredAppColorScheme)
    }
  }
}
