import CoreModels
import Foundation
import Networking
import Testing

@testable import AppShell

/// A 400 on /auth/refresh is a hard failure: the stored token can never recover,
/// so the session must fail closed to login instead of looping on retries
/// (2026-07-17 incident: refresh 400 stranded every client on a retry dead-end
/// because only 401 triggered the clean logout path).
@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func rejectedAccessTokenWithRefreshBadRequestLogsOut() async throws {
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
  await repository.setForcedError(.backend(statusCode: 400, code: .validationError, issues: []))

  await #expect(throws: SessionStateReaderError.authenticationExpired) {
    _ = try await session.recoverAccessToken(rejectedAccessToken: rejectedAccessToken)
  }

  #expect(session.state == .anonymous)
  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func automaticRefreshFailureRunsLogoutCleanupBeforeTokenClear() async throws {
  let repository = InMemoryAuthRepository()
  let signup = try await repository.signup(
    phone: "13800000001", password: "password123", role: .coach)
  let store = InMemoryTokenStore(
    access: signup.accessToken,
    refresh: signup.refreshToken,
    user: signup.user
  )
  let spy = AutomaticLogoutCleanupSpy()
  let session = Session(auth: repository, tokenStore: store) {
    await spy.record(tokenWasAvailable: await store.accessToken() != nil)
  }
  await session.bootstrap()
  let rejectedAccessToken = try #require(await store.accessToken())
  let forcedError = AuthRepositoryError.backend(
    statusCode: 400, code: .validationError, issues: [])
  await repository.setForcedError(forcedError)

  await #expect(throws: forcedError) {
    _ = try await session.recoverAccessToken(rejectedAccessToken: rejectedAccessToken)
  }

  #expect(await spy.callCount == 1)
  #expect(await spy.tokenWasAvailable == true)
  #expect(await store.accessToken() == nil)
}

private actor AutomaticLogoutCleanupSpy {
  private(set) var callCount = 0
  private(set) var tokenWasAvailable = false

  func record(tokenWasAvailable: Bool) {
    callCount += 1
    self.tokenWasAvailable = tokenWasAvailable
  }
}
