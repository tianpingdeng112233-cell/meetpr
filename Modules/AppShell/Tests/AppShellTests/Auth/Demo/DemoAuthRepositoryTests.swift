import Testing

@testable import AppShell

@available(iOS 17.0, macOS 14.0, *)
@Test func demoSignupReturnsSeededCoachAndTokens() async throws {
  let repository = DemoAuthRepository()

  let result = try await repository.signup(
    phone: "13900000000",
    password: "ignored",
    role: .coachedStudent
  )

  #expect(result.user == DemoUserSeed.coach)
  #expect(result.accessToken == DemoUserSeed.accessToken)
  #expect(result.refreshToken == DemoUserSeed.refreshToken)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoLoginReturnsSeededCoachAndTokens() async throws {
  let repository = DemoAuthRepository()

  let result = try await repository.login(phone: "13900000000", password: "ignored")

  #expect(result.user == DemoUserSeed.coach)
  #expect(result.accessToken == DemoUserSeed.accessToken)
  #expect(result.refreshToken == DemoUserSeed.refreshToken)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoRefreshReturnsSeededTokenPair() async throws {
  let repository = DemoAuthRepository()

  let tokens = try await repository.refresh(refreshToken: "ignored")

  #expect(tokens.accessToken == DemoUserSeed.accessToken)
  #expect(tokens.refreshToken == DemoUserSeed.refreshToken)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func demoRefreshIsDeterministic() async throws {
  let repository = DemoAuthRepository()

  let first = try await repository.refresh(refreshToken: "old-refresh")
  let second = try await repository.refresh(refreshToken: "another-refresh")

  #expect(first == second)
}
