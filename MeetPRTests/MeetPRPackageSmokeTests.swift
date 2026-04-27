import AppShell
import CoachKit
import CoreModels
import DesignSystem
import Networking
import StudentKit
import SwiftUI
import Testing

@Test func coreModelsSmoke() throws {
  let user = User(id: UUID(), role: .student, displayName: "Student")
  let data = try JSONEncoder().encode(user)
  let decodedUser = try JSONDecoder().decode(User.self, from: data)

  #expect(decodedUser == user)
}

@Test func networkingSmoke() {
  #expect(APIClient.shared.baseURL.host() == "api.meetpr.local")
  #expect(Endpoint.coach.path == "/coach")
}

@MainActor
@Test func designSystemSmoke() {
  _ = PrimaryButton("Continue") {}
  #expect(Color.MeetPR.brandRed != .clear)
}

@MainActor
@Test func appShellSmoke() {
  let session = Session(api: APIClient.shared)

  #expect(session.state == .anonymous)
  session.fakeLogin(role: .coach)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session state")
    return
  }

  #expect(user.role == .coach)
}

@MainActor
@Test func coachKitSmoke() {
  _ = CoachRootView()
}

@MainActor
@Test func studentKitSmoke() {
  _ = StudentRootView()
}
