import Testing

@testable import AppShell

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryTokenStoreSavesAndLoadsTokens() async {
  let store = InMemoryTokenStore()

  await store.save(access: "access-1", refresh: "refresh-1")

  #expect(await store.accessToken() == "access-1")
  #expect(await store.refreshToken() == "refresh-1")
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryTokenStoreSavesAndLoadsCachedUser() async {
  let store = InMemoryTokenStore()
  let user = AuthTestSupport.user()

  await store.saveUser(user)

  #expect(await store.cachedUser() == user)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryTokenStoreClearRemovesTokensAndUser() async {
  let store = InMemoryTokenStore(access: "access", refresh: "refresh", user: AuthTestSupport.user())

  await store.clear()

  #expect(await store.accessToken() == nil)
  #expect(await store.refreshToken() == nil)
  #expect(await store.cachedUser() == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func inMemoryTokenStoreOverwritesTokens() async {
  let store = InMemoryTokenStore(access: "old-access", refresh: "old-refresh")

  await store.save(access: "new-access", refresh: "new-refresh")

  #expect(await store.accessToken() == "new-access")
  #expect(await store.refreshToken() == "new-refresh")
}
