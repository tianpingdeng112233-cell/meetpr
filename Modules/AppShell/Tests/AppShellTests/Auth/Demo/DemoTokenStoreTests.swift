import Testing

@testable import AppShell

@available(iOS 17.0, macOS 14.0, *)
@Test func demoTokenStoreStartsWithAccessToken() async {
  let store = DemoTokenStore()

  #expect(await store.accessToken() == DemoUserSeed.accessToken)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoTokenStoreStartsWithRefreshToken() async {
  let store = DemoTokenStore()

  #expect(await store.refreshToken() == DemoUserSeed.refreshToken)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoTokenStoreStartsWithCachedCoach() async {
  let store = DemoTokenStore()

  #expect(await store.cachedUser() == DemoUserSeed.coach)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoTokenStoreSaveDoesNotOverrideSeededValues() async {
  let store = DemoTokenStore()
  await store.save(access: "custom-access", refresh: "custom-refresh")
  await store.saveUser(AuthTestSupport.user(role: .coachedStudent))

  #expect(await store.accessToken() == DemoUserSeed.accessToken)
  #expect(await store.refreshToken() == DemoUserSeed.refreshToken)
  #expect(await store.cachedUser() == DemoUserSeed.coach)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoTokenStoreClearKeepsSeededValues() async {
  let store = DemoTokenStore()
  await store.clear()

  #expect(await store.accessToken() == DemoUserSeed.accessToken)
  #expect(await store.refreshToken() == DemoUserSeed.refreshToken)
  #expect(await store.cachedUser() == DemoUserSeed.coach)
}
