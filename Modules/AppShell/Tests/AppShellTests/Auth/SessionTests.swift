import CoreModels
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapWithoutCompleteCacheClearsStoreAndStaysAnonymous() async {
  let store = InMemoryTokenStore(access: "orphan-access")
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapWithRefreshSuccessAuthenticatesCachedUserAndRotatesTokens() async throws {
  let repository = InMemoryAuthRepository()
  let signup = try await repository.signup(
    phone: "13800000001", password: "password123", role: .coach)
  let store = InMemoryTokenStore(
    access: signup.accessToken,
    refresh: signup.refreshToken,
    user: signup.user
  )
  let session = Session(auth: repository, tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .authenticated(signup.user))
  #expect(await store.accessToken() != signup.accessToken)
  #expect(await store.refreshToken() != signup.refreshToken)
  #expect(await store.cachedUser() == signup.user)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapWithInvalidRefreshClearsStoreAndReturnsAnonymous() async {
  let store = InMemoryTokenStore(
    access: "access", refresh: "invalid-refresh", user: AuthTestSupport.user())
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapWithNetworkRefreshFailureClearsStoreAndReturnsAnonymous() async {
  let user = AuthTestSupport.user()
  let store = InMemoryTokenStore(access: "access", refresh: "refresh", user: user)
  let repository = InMemoryAuthRepository(forcedError: .network)
  let session = Session(auth: repository, tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func signupAuthenticatesAndPersistsTokens() async throws {
  let store = InMemoryTokenStore()
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: store)

  try await session.signup(phone: "13800000001", password: "password123", role: .coach)

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session after signup")
    return
  }

  #expect(user.role == .coach)
  #expect(await store.accessToken() != nil)
  #expect(await store.refreshToken() != nil)
  #expect(await store.cachedUser() == user)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func loginAuthenticatesAndPersistsTokens() async throws {
  let repository = InMemoryAuthRepository()
  _ = try await repository.signup(
    phone: "13800000001", password: "password123", role: .coachedStudent)
  let store = InMemoryTokenStore()
  let session = Session(auth: repository, tokenStore: store)

  try await session.login(phone: "13800000001", password: "password123")

  guard case .authenticated(let user) = session.state else {
    Issue.record("Expected authenticated session after login")
    return
  }

  #expect(user.role == .coachedStudent)
  #expect(await store.accessToken() != nil)
  #expect(await store.refreshToken() != nil)
  #expect(await store.cachedUser() == user)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func logoutClearsStoreAndCallsLogoutHookOnce() async throws {
  let store = InMemoryTokenStore()
  let spy = LogoutSpy()
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: store) {
    await spy.record()
  }

  try await session.signup(phone: "13800000001", password: "password123", role: .coach)
  await session.logout()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
  #expect(await spy.count() == 1)
}

private actor LogoutSpy {
  private var logoutCount = 0

  func record() {
    logoutCount += 1
  }

  func count() -> Int {
    logoutCount
  }
}
