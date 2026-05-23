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

  private func fixedResult() -> AuthResult {
    AuthResult(
      user: user,
      accessToken: DemoUserSeed.accessToken,
      refreshToken: DemoUserSeed.refreshToken
    )
  }
}
