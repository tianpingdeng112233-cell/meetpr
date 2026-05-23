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
      let planStore = InMemoryPlanStore()
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
          studentPlans: InMemoryStudentPlanRepository(store: planStore),
          studentLogs: InMemoryStudentTrainingLogRepository(
            seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
          ),
          studentFeedback: InMemoryStudentFeedbackRepository(
            seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
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
      let tokenStore: any TokenStoring = TokenStore()
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
