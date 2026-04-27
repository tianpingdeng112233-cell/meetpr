import AppShell
import Networking
import SwiftUI

@main
struct MeetPRApp: App {
  @State private var session = Session(api: APIClient.shared)

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(session)
    }
  }
}
