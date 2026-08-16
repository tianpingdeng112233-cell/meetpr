import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public final class DemoAuthRepository: AuthRepository, Sendable {
  private let user: User

  public init(user: User = DemoUserSeed.coach) {
    self.user = user
  }

  public func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    fixedResult()
  }

  public func login(phone: String, password: String) async throws -> AuthResult {
    fixedResult()
  }

  public func refresh(refreshToken: String) async throws -> TokenPair {
    TokenPair(
      accessToken: DemoUserSeed.accessToken,
      refreshToken: DemoUserSeed.refreshToken
    )
  }

  public func fetchChallenge() async throws -> AuthChallenge {
    AuthChallenge(
      nonce: "demo-challenge",
      expiresAt: Date().addingTimeInterval(10 * 60)
    )
  }

  public func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?,
    timezone: String
  ) async throws -> AuthResult {
    fixedResult()
  }

  public func signInWithGoogle(idToken: String, timezone: String) async throws -> AuthResult {
    fixedResult()
  }

  public func registerWithEmail(
    email: String,
    password: String,
    timezone: String
  ) async throws -> AuthResult {
    fixedResult()
  }

  public func loginWithEmail(email: String, password: String) async throws -> AuthResult {
    fixedResult()
  }

  public func requestPasswordReset(email: String) async throws {}

  public func resetPassword(email: String, code: String, newPassword: String) async throws {}

  public func updateTimezone(_ timezone: String, accessToken: String) async throws {}

  private func fixedResult() -> AuthResult {
    AuthResult(
      user: user,
      accessToken: DemoUserSeed.accessToken,
      refreshToken: DemoUserSeed.refreshToken
    )
  }
}
