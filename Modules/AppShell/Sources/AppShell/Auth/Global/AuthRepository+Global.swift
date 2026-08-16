import CoreModels
import Foundation
import Networking

extension NetworkingAuthRepository {
  public func fetchChallenge() async throws -> AuthChallenge {
    do {
      let response = try await api.fetchAuthChallenge()
      return AuthChallenge(nonce: response.nonce, expiresAt: response.expiresAt)
    } catch {
      throw Self.map(error)
    }
  }

  public func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?,
    timezone: String
  ) async throws -> AuthResult {
    do {
      let response = try await api.signInWithApple(
        AppleAuthRequestDTO(
          identityToken: identityToken,
          nonce: nonce,
          role: .coachedStudent,
          authorizationCode: authorizationCode,
          timezone: timezone
        )
      )
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func signInWithGoogle(idToken: String, timezone: String) async throws -> AuthResult {
    do {
      let response = try await api.signInWithGoogle(
        GoogleAuthRequestDTO(
          idToken: idToken,
          role: .coachedStudent,
          timezone: timezone
        )
      )
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func registerWithEmail(
    email: String,
    password: String,
    timezone: String
  ) async throws -> AuthResult {
    do {
      let response = try await api.registerWithEmail(
        EmailRegisterRequestDTO(
          email: email,
          password: password,
          role: .coachedStudent,
          timezone: timezone
        )
      )
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func loginWithEmail(email: String, password: String) async throws -> AuthResult {
    do {
      let response = try await api.loginWithEmail(
        EmailLoginRequestDTO(email: email, password: password)
      )
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func requestPasswordReset(email: String) async throws {
    do {
      try await api.requestPasswordReset(EmailForgotRequestDTO(email: email))
    } catch {
      throw Self.map(error)
    }
  }

  public func resetPassword(email: String, code: String, newPassword: String) async throws {
    do {
      try await api.resetPassword(
        EmailResetRequestDTO(email: email, code: code, newPassword: newPassword)
      )
    } catch {
      throw Self.map(error)
    }
  }

  public func updateTimezone(_ timezone: String, accessToken: String) async throws {
    do {
      try await api.updateTimezone(timezone, accessToken: accessToken)
    } catch {
      throw Self.map(error)
    }
  }
}

extension InMemoryAuthRepository {
  public func fetchChallenge() async throws -> AuthChallenge {
    if let forcedError {
      throw forcedError
    }
    return AuthChallenge(
      nonce: "in-memory-challenge",
      expiresAt: Date().addingTimeInterval(10 * 60)
    )
  }

  public func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?,
    timezone: String
  ) async throws -> AuthResult {
    try globalResult(identifier: "apple@example.com")
  }

  public func signInWithGoogle(idToken: String, timezone: String) async throws -> AuthResult {
    try globalResult(identifier: "google@example.com")
  }

  public func registerWithEmail(
    email: String,
    password: String,
    timezone: String
  ) async throws -> AuthResult {
    try globalResult(identifier: email)
  }

  public func loginWithEmail(email: String, password: String) async throws -> AuthResult {
    try globalResult(identifier: email)
  }

  public func requestPasswordReset(email: String) async throws {
    if let forcedError {
      throw forcedError
    }
  }

  public func resetPassword(email: String, code: String, newPassword: String) async throws {
    if let forcedError {
      throw forcedError
    }
  }

  public func updateTimezone(_ timezone: String, accessToken: String) async throws {
    if let forcedError {
      throw forcedError
    }
  }

  private func globalResult(identifier: String) throws -> AuthResult {
    if let forcedError {
      throw forcedError
    }
    let now = Date()
    return AuthResult(
      user: User(
        id: UUID(),
        phone: identifier,
        name: nil,
        unitSystem: .metric,
        role: .coachedStudent,
        createdAt: now,
        updatedAt: now
      ),
      accessToken: nextToken(prefix: "access"),
      refreshToken: nextToken(prefix: "refresh")
    )
  }
}
