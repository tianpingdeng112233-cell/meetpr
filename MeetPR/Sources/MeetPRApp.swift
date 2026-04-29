import AppShell
import CoachKit
import Networking
import SwiftData
import SwiftUI

@main
struct MeetPRApp: App {
  @State private var session: Session = {
    let api = APIClient.shared
    let auth = NetworkingAuthRepository(api: api)
    let tokenStore = TokenStore()
    return Session(auth: auth, tokenStore: tokenStore, onLogout: nil)
  }()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(session)
        .task {
          await session.bootstrap()
        }
        .modelContainer(
          for: [
            DraftTrainingPlan.self,
            DraftPlanDay.self,
            DraftPlanExercise.self,
          ]
        )
    }
  }
}
