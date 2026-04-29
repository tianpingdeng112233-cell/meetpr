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
    let api = APIClient.shared
    let auth = NetworkingAuthRepository(api: api)
    let tokenStore = TokenStore()
    let draftStore = DraftStore.shared
    self.draftStore = draftStore
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
