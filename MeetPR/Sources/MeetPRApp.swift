import AppShell
import CoachKit
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
      let auth: any AuthRepository = DemoAuthRepository(user: demoUser)
      let tokenStore: any TokenStoring = DemoTokenStore(user: demoUser)
      let session = Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: {
          try? await draftStore.deleteAll()
        }
      )
      return RootDependencies(
        rootView: RootView(
          coachPlans: InMemoryPlanRepository.preview(store: planStore),
          // Demo coach: personal (used 23) + unused single-use + 6-day
          // time-limited seed codes (spec 031 D10).
          coachInviteCodes: InMemoryInviteCodeRepository(
            coachId: StudentDemoSeed.coachID,
            seed: InMemoryInviteCodeRepository.demoSeed(coachId: StudentDemoSeed.coachID)
          ),
          studentPlans: InMemoryStudentPlanRepository(store: planStore),
          studentLogs: InMemoryStudentTrainingLogRepository(
            seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
          ),
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
          draftStore: draftStore
        ),
        session: session
      )
    }
  #else
    private static func makeRootDependencies(draftStore: DraftStore) -> RootDependencies {
      let api = APIClient.shared
      let auth: any AuthRepository = NetworkingAuthRepository(api: api)
      let tokenStore: any TokenStoring = KeychainTokenStore()
      let session = Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: {
          try? await draftStore.deleteAll()
        }
      )
      session.bindToErrors(api.errorStream)
      return RootDependencies(
        rootView: RootView(
          coachPlans: BackendPlanRepository(api: api, session: session, cache: PlanCache()),
          coachInviteCodes: BackendInviteCodeRepository(api: api, session: session),
          studentPlans: BackendStudentPlanRepository(
            api: api,
            session: session,
            cache: StudentPlanCache()
          ),
          studentLogs: BackendStudentTrainingLogRepository(
            api: api,
            session: session,
            cache: TrainingLogCache()
          ),
          studentFeedback: BackendStudentFeedbackRepository(
            api: api,
            session: session,
            cache: FeedbackCache()
          ),
          // e1RM stays fully on-device in V0.1 (spec 028 persistence ladder):
          // JSON files under Documents/e1rm/, no backend endpoint.
          studentE1RM: LocalE1RMRepository(),
          studentReadiness: BackendReadinessRepository(api: api, session: session),
          // Set-video uploads (spec 027): backend /uploads/* pipeline; the
          // setLog ↔ attachment mapping persists on-device only in V0.1.
          studentVideoUploads: .backend(api: api, session: session),
          // Bind + onboarding are cache-free by design (spec 031/032 §9):
          // both must read live server state.
          studentBind: BackendBindRepository(api: api, session: session),
          studentOnboarding: BackendOnboardingRepository(api: api, session: session),
          // Coach-side video wall (spec 029 second pass): server-side
          // metadata + per-item presigned playback URLs.
          coachStudentVideos: BackendCoachStudentVideoRepository(api: api, session: session),
          // Growth-tab family mapping reads the coach-owned full plan tree
          // (the student projection only carries the current week).
          coachFamilyMapProvider: BackendCoachPlanFamilyMapProvider(api: api, session: session),
          draftStore: draftStore
        ),
        session: session
      )
    }
  #endif

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
    }
  }
}
