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

    #if DEMO_MODE
      let planStore = InMemoryPlanStore()
      let auth: any AuthRepository = DemoAuthRepository()
      let tokenStore: any TokenStoring = DemoTokenStore()
      let session = Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: {
          try? await draftStore.deleteAll()
        }
      )
      rootView = RootView(
        coachPlans: InMemoryPlanRepository.preview(store: planStore),
        studentPlans: InMemoryStudentPlanRepository(store: planStore),
        studentLogs: InMemoryStudentTrainingLogRepository(
          seed: StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
        ),
        studentFeedback: InMemoryStudentFeedbackRepository(
          seed: StudentDemoSeed.makeFeedback(studentID: StudentDemoSeed.studentID)
        ),
        draftStore: draftStore
      )
    #else
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
      rootView = RootView(
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
      )
    #endif

    _session = State(initialValue: session)
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
    }
  }
}
