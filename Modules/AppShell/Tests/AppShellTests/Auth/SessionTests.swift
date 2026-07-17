import CoreModels
import Foundation
import Networking
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
@Test(
  arguments: [
    AuthErrorCode.invalidCredentials,
    .invalidRefresh,
    .phoneTaken,
    .rateLimited,
    .refreshExpired,
    .validationError,
  ])
func bootstrapWithAnyRecognizedUnauthorizedErrorClearsStoreAndReturnsAnonymous(
  code: AuthErrorCode
) async {
  let store = InMemoryTokenStore(
    access: "access", refresh: "refresh", user: AuthTestSupport.user())
  let repository = InMemoryAuthRepository(
    forcedError: .backend(statusCode: 401, code: code, issues: []))
  let session = Session(auth: repository, tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(
  arguments: [
    AuthRepositoryError.network,
    .server(statusCode: 503),
    .decoding,
    .backend(statusCode: 429, code: .rateLimited, issues: []),
  ])
func bootstrapWithTransientRefreshFailureKeepsSessionAndCredentials(
  error: AuthRepositoryError
) async {
  let user = AuthTestSupport.user()
  let store = InMemoryTokenStore(access: "access", refresh: "refresh", user: user)
  let repository = InMemoryAuthRepository(forcedError: error)
  let session = Session(auth: repository, tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .authenticated(user))
  #expect(await store.accessToken() == "access")
  #expect(await store.refreshToken() == "refresh")
  #expect(await store.cachedUser() == user)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapWithUnknownRefreshFailureClearsStoreAndReturnsAnonymous() async {
  let user = AuthTestSupport.user()
  let store = InMemoryTokenStore(access: "access", refresh: "refresh", user: user)
  let session = Session(auth: UnknownFailureAuthRepository(), tokenStore: store)

  await session.bootstrap()

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapIsNoOpWhenSessionAlreadyAuthenticated() async throws {
  // The root `.task` runs bootstrap() unconditionally. Once an interactive
  // login has settled the session to .authenticated, a (re-)entered bootstrap
  // must not re-stir it through .authenticating — that teardown is what
  // cancels the student tabs' first-load .task on high-latency networks.
  let repository = InMemoryAuthRepository()
  _ = try await repository.signup(
    phone: "13800000002", password: "password123", role: .coachedStudent)
  let store = InMemoryTokenStore()
  let session = Session(auth: repository, tokenStore: store)
  try await session.login(phone: "13800000002", password: "password123")
  guard case .authenticated(let user) = session.state else {
    Issue.record("Precondition: expected authenticated session after login")
    return
  }
  let tokenAfterLogin = await store.accessToken()

  await session.bootstrap()

  // No-op: state unchanged and no token rotation (refresh never ran).
  #expect(session.state == .authenticated(user))
  #expect(await store.accessToken() == tokenAfterLogin)
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

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accessTokenRefreshesExpiredJWTBeforeReturningIt() async throws {
  let repository = InMemoryAuthRepository()
  let signup = try await repository.signup(
    phone: "13800000001", password: "password123", role: .coach)
  let expiredAccess = jwt(exp: Date().addingTimeInterval(-60))
  let store = InMemoryTokenStore(
    access: expiredAccess,
    refresh: signup.refreshToken,
    user: signup.user
  )
  let session = Session(auth: repository, tokenStore: store)

  await session.bootstrap()
  let bootstrapToken = try await session.accessToken()
  await store.save(access: expiredAccess, refresh: await store.refreshToken() ?? "")

  let token = try await session.accessToken()

  #expect(token != expiredAccess)
  #expect(token != bootstrapToken)
  #expect(await store.accessToken() == token)
  #expect(session.state == .authenticated(signup.user))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(
  arguments: [
    AuthRepositoryError.network,
    .server(statusCode: 503),
    .decoding,
    .backend(statusCode: 429, code: .rateLimited, issues: []),
  ])
func accessTokenTransientRefreshFailureKeepsAuthenticatedSession(
  error: AuthRepositoryError
) async throws {
  let repository = InMemoryAuthRepository()
  let signup = try await repository.signup(
    phone: "13800000001", password: "password123", role: .coach)
  let expiredAccess = jwt(exp: Date().addingTimeInterval(-60))
  let store = InMemoryTokenStore(
    access: signup.accessToken,
    refresh: signup.refreshToken,
    user: signup.user
  )
  let session = Session(auth: repository, tokenStore: store)
  await session.bootstrap()
  let refresh = await store.refreshToken() ?? ""
  await store.save(access: expiredAccess, refresh: refresh)
  await repository.setForcedError(error)

  await #expect(throws: error) {
    _ = try await session.accessToken()
  }

  #expect(session.state == .authenticated(signup.user))
  #expect(await store.accessToken() == expiredAccess)
  #expect(await store.refreshToken() == refresh)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rejectedAccessTokenRefreshesWithoutLoggingOut() async throws {
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
  let rejectedAccessToken = try #require(await store.accessToken())

  let recoveredAccessToken = try await session.recoverAccessToken(
    rejectedAccessToken: rejectedAccessToken)

  #expect(recoveredAccessToken != rejectedAccessToken)
  #expect(await store.accessToken() == recoveredAccessToken)
  #expect(session.state == .authenticated(signup.user))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func staleUnauthorizedResponseReusesAlreadyRotatedAccessToken() async throws {
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
  let staleAccessToken = try #require(await store.accessToken())
  let currentAccessToken = try await session.recoverAccessToken(
    rejectedAccessToken: staleAccessToken)
  await repository.setForcedError(.network)

  let reusedAccessToken = try await session.recoverAccessToken(
    rejectedAccessToken: staleAccessToken)

  #expect(reusedAccessToken == currentAccessToken)
  #expect(session.state == .authenticated(signup.user))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(
  arguments: [
    AuthErrorCode.invalidCredentials,
    .invalidRefresh,
    .phoneTaken,
    .rateLimited,
    .refreshExpired,
    .validationError,
  ])
func rejectedAccessTokenWithAnyRecognizedUnauthorizedErrorLogsOut(
  code: AuthErrorCode
) async throws {
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
  let rejectedAccessToken = try #require(await store.accessToken())
  await repository.setForcedError(.backend(statusCode: 401, code: code, issues: []))

  await #expect(throws: SessionStateReaderError.authenticationExpired) {
    _ = try await session.recoverAccessToken(rejectedAccessToken: rejectedAccessToken)
  }

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
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

private struct UnknownRefreshError: Error {}

private struct UnknownFailureAuthRepository: AuthRepository {
  func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    throw UnknownRefreshError()
  }

  func login(phone: String, password: String) async throws -> AuthResult {
    throw UnknownRefreshError()
  }

  func refresh(refreshToken: String) async throws -> TokenPair {
    throw UnknownRefreshError()
  }
}

private func jwt(exp: Date) -> String {
  let payload = #"{"exp":\#(Int(exp.timeIntervalSince1970))}"#
  return "e30.\(base64URL(Data(payload.utf8))).sig"
}

private func base64URL(_ data: Data) -> String {
  data.base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}
