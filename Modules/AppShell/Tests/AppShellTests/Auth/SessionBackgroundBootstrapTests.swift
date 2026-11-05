import CoreModels
import Foundation
import Testing

@testable import AppShell

@MainActor @Test func concurrentBackgroundBootstrapWaitsForForegroundAuthentication() async throws {
  let auth = InMemoryAuthRepository()
  let login = try await auth.signup(
    phone: "13800000001", password: "password123", role: .coachedStudent)
  let store = SuspendedBootstrapStore(refresh: login.refreshToken, user: login.user)
  let session = Session(auth: auth, tokenStore: store)
  let foreground = Task { await session.bootstrap() }
  while !(await store.entered) { await Task.yield() }
  let background = Task {
    await session.bootstrap()
    return session.state
  }
  for _ in 0..<20 { await Task.yield() }
  await store.release()
  await foreground.value
  #expect(await background.value == .authenticated(login.user))
}

private actor SuspendedBootstrapStore: TokenStoring {
  let refresh: String
  let user: User
  var entered = false
  var continuation: CheckedContinuation<String?, Never>?
  init(refresh: String, user: User) {
    self.refresh = refresh
    self.user = user
  }
  func refreshToken() async -> String? {
    entered = true
    return await withCheckedContinuation { continuation = $0 }
  }
  func release() {
    continuation?.resume(returning: refresh)
    continuation = nil
  }
  func save(access: String, refresh: String) async {}
  func saveUser(_ user: User) async {}
  func accessToken() async -> String? { nil }
  func cachedUser() async -> User? { user }
  func clear() async {}
}
