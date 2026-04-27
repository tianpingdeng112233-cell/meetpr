import CoreModels
import Networking
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func sessionMovesThroughStubAuthenticationStates() {
  let session = Session(api: APIClient.shared)

  #expect(session.state == .anonymous)

  session.fakeLogin(role: .coach)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session state")
    return
  }

  #expect(user.role == .coach)

  session.logout()

  #expect(session.state == .anonymous)
}
