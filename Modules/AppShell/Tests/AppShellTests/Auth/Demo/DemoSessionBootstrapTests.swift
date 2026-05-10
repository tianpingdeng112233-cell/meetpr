import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func demoSessionBootstrapAuthenticatesSeededCoach() async {
  let session = Session(auth: DemoAuthRepository(), tokenStore: DemoTokenStore())

  await session.bootstrap()

  #expect(session.state == .authenticated(DemoUserSeed.coach))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func demoSessionRefreshDoesNotThrow() async throws {
  let repository = DemoAuthRepository()

  let tokens = try await repository.refresh(refreshToken: DemoUserSeed.refreshToken)

  #expect(
    tokens
      == TokenPair(
        accessToken: DemoUserSeed.accessToken,
        refreshToken: DemoUserSeed.refreshToken
      ))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func demoSessionLogoutIsLocalAndFreshBootstrapRestoresCoach() async {
  let store = DemoTokenStore()
  let session = Session(auth: DemoAuthRepository(), tokenStore: store)

  await session.bootstrap()
  await session.logout()

  #expect(session.state == .anonymous)
  #expect(await store.cachedUser() == DemoUserSeed.coach)

  let freshSession = Session(auth: DemoAuthRepository(), tokenStore: store)
  await freshSession.bootstrap()

  #expect(freshSession.state == .authenticated(DemoUserSeed.coach))
}
