import AppShell
import CoachKit
import Networking
import SwiftData
import SwiftUI

@main
@MainActor
struct MeetPRApp: App {
  private let draftStore: DraftStore
  @State private var session: Session

  init() {
    let draftStore = DraftStore.shared
    self.draftStore = draftStore

    #if DEMO_MODE
      #if DEMO_USER_STUDENT
        let demoUser = DemoUserSeed.coachedStudent
      #else
        let demoUser = DemoUserSeed.coach
      #endif
      let auth: any AuthRepository = DemoAuthRepository(user: demoUser)
      let tokenStore: any TokenStoring = DemoTokenStore(user: demoUser)
    #else
      let api = APIClient.shared
      let auth: any AuthRepository = NetworkingAuthRepository(api: api)
      let tokenStore: any TokenStoring = TokenStore()
    #endif

    _session = State(
      initialValue: Session(
        auth: auth,
        tokenStore: tokenStore,
        onLogout: {
          try? await draftStore.deleteAll()
        }
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      RootView()
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
