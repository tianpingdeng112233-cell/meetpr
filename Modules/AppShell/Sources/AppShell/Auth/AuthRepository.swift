import CoreModels
import Foundation
import Networking

public struct AuthResult: Sendable, Equatable {
  public let user: User
  public let accessToken: String
  public let refreshToken: String

  public init(user: User, accessToken: String, refreshToken: String) {
    self.user = user
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public struct TokenPair: Sendable, Equatable {
  public let accessToken: String
  public let refreshToken: String

  public init(accessToken: String, refreshToken: String) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public struct AuthChallenge: Sendable, Equatable {
  public let nonce: String
  public let expiresAt: Date

  public init(nonce: String, expiresAt: Date) {
    self.nonce = nonce
    self.expiresAt = expiresAt
  }
}

public struct AuthValidationIssue: Sendable, Equatable {
  public let path: [String]
  public let message: String

  public init(path: [String], message: String) {
    self.path = path
    self.message = message
  }
}

public enum AuthErrorCode: String, Sendable, Equatable {
  case invalidCredentials = "AUTH_INVALID_CREDENTIALS"
  case invalidIdentityToken = "AUTH_INVALID_IDENTITY_TOKEN"
  case invalidResetCode = "AUTH_INVALID_RESET_CODE"
  case invalidTimezone = "INVALID_TIMEZONE"
  case emailTaken = "AUTH_EMAIL_TAKEN"
  case invalidRefresh = "AUTH_INVALID_REFRESH"
  case phoneTaken = "AUTH_PHONE_TAKEN"
  case rateLimited = "RATE_LIMITED"
  case registrationDisabled = "AUTH_REGISTRATION_DISABLED"
  case registrationNotAllowed = "AUTH_REGISTRATION_NOT_ALLOWED"
  case refreshExpired = "AUTH_REFRESH_EXPIRED"
  case validationError = "VALIDATION_ERROR"
}

public enum AuthRepositoryError: Error, Sendable, Equatable {
  case backend(statusCode: Int, code: AuthErrorCode, issues: [AuthValidationIssue])
  case decoding
  case network
  case server(statusCode: Int)

  public var clearsBootstrapSession: Bool {
    switch self {
    case .backend(401, _, _):
      true
    case .backend(400, _, _):
      // A 400 on /auth/refresh means the request itself is malformed — retrying the
      // same stored token can never succeed, so keeping the session strands the user
      // on an endless retry dead-end (2026-07-17 BindGate incident). Fail closed.
      true
    case .backend, .decoding, .network, .server:
      false
    }
  }
}

public protocol AuthRepository: Sendable {
  func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult
  func login(phone: String, password: String) async throws -> AuthResult
  func fetchChallenge() async throws -> AuthChallenge
  func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?,
    timezone: String
  ) async throws -> AuthResult
  func signInWithGoogle(idToken: String, timezone: String) async throws -> AuthResult
  func registerWithEmail(email: String, password: String, timezone: String) async throws
    -> AuthResult
  func loginWithEmail(email: String, password: String) async throws -> AuthResult
  func requestPasswordReset(email: String) async throws
  func resetPassword(email: String, code: String, newPassword: String) async throws
  func updateTimezone(_ timezone: String, accessToken: String) async throws
  func refresh(refreshToken: String) async throws -> TokenPair
}

public struct NetworkingAuthRepository: AuthRepository {
  let api: APIClient

  public init(api: APIClient) {
    self.api = api
  }

  public func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    do {
      let response = try await api.register(
        phone: Self.wirePhone(from: phone),
        password: password,
        role: role
      )
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func login(phone: String, password: String) async throws -> AuthResult {
    do {
      let response = try await api.login(phone: Self.wirePhone(from: phone), password: password)
      return try Self.result(from: response)
    } catch {
      throw Self.map(error)
    }
  }

  public func refresh(refreshToken: String) async throws -> TokenPair {
    do {
      let response = try await api.refresh(refreshToken: refreshToken)
      return TokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken)
    } catch {
      throw Self.map(error)
    }
  }

  private static func wirePhone(from nationalPhone: String) -> String {
    if nationalPhone.hasPrefix("+") {
      return nationalPhone
    }
    return "+86" + nationalPhone
  }

  static func result(from response: AuthResultDTO) throws -> AuthResult {
    do {
      return AuthResult(
        user: try response.user.toUser(),
        accessToken: response.accessToken,
        refreshToken: response.refreshToken
      )
    } catch {
      throw AuthRepositoryError.decoding
    }
  }

  static func map(_ error: Error) -> AuthRepositoryError {
    if let authError = error as? AuthRepositoryError {
      return authError
    }

    if let apiError = error as? APIError {
      return map(apiError)
    }

    if let apiError = error as? APIClientError {
      return map(apiError)
    }

    if error is DecodingError {
      return .decoding
    }

    if error is URLError {
      return .network
    }

    return .network
  }

  private static func map(_ error: APIClientError) -> AuthRepositoryError {
    switch error {
    case .invalidResponse:
      return .network
    case .httpStatus(let statusCode, let data):
      return mapHTTPStatus(statusCode, data: data)
    }
  }

  private static func map(_ error: APIError) -> AuthRepositoryError {
    switch error {
    case .invalidResponse:
      return .network
    case .authInvalid:
      return .backend(statusCode: 401, code: .invalidRefresh, issues: [])
    case .httpStatus(let statusCode, let data):
      return mapHTTPStatus(statusCode, data: data)
    }
  }

  private static func mapHTTPStatus(_ statusCode: Int, data: Data) -> AuthRepositoryError {
    if let envelope = try? JSONDecoder().decode(AuthErrorEnvelopeDTO.self, from: data) {
      guard let code = AuthErrorCode(rawValue: envelope.error) else {
        return .network
      }

      let issues =
        envelope.issues?.map {
          AuthValidationIssue(path: $0.path, message: $0.message)
        } ?? []
      return .backend(statusCode: statusCode, code: code, issues: issues)
    }

    if statusCode >= 500 {
      return .server(statusCode: statusCode)
    }

    return .network
  }
}

public actor InMemoryAuthRepository: AuthRepository {
  private struct StoredUser: Sendable {
    let user: User
    let password: String
    let refreshToken: String
  }

  var forcedError: AuthRepositoryError?
  private var usersByPhone: [String: StoredUser] = [:]
  private var phoneByRefreshToken: [String: String] = [:]
  private var tokenCounter = 0

  public init(forcedError: AuthRepositoryError? = nil) {
    self.forcedError = forcedError
  }

  public func setForcedError(_ error: AuthRepositoryError?) {
    forcedError = error
  }

  public func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    if let forcedError {
      throw forcedError
    }

    if usersByPhone[phone] != nil {
      throw AuthRepositoryError.backend(statusCode: 409, code: .phoneTaken, issues: [])
    }

    let now = Date()
    let refreshToken = nextToken(prefix: "refresh")
    let user = User(
      id: UUID(),
      phone: phone,
      name: nil,
      unitSystem: .metric,
      role: role,
      createdAt: now,
      updatedAt: now
    )
    let storedUser = StoredUser(user: user, password: password, refreshToken: refreshToken)
    usersByPhone[phone] = storedUser
    phoneByRefreshToken[refreshToken] = phone

    return AuthResult(
      user: user,
      accessToken: nextToken(prefix: "access"),
      refreshToken: refreshToken
    )
  }

  public func login(phone: String, password: String) async throws -> AuthResult {
    if let forcedError {
      throw forcedError
    }

    guard let storedUser = usersByPhone[phone], storedUser.password == password else {
      throw AuthRepositoryError.backend(statusCode: 401, code: .invalidCredentials, issues: [])
    }

    let refreshToken = nextToken(prefix: "refresh")
    phoneByRefreshToken.removeValue(forKey: storedUser.refreshToken)
    usersByPhone[phone] = StoredUser(
      user: storedUser.user,
      password: storedUser.password,
      refreshToken: refreshToken
    )
    phoneByRefreshToken[refreshToken] = phone

    return AuthResult(
      user: storedUser.user,
      accessToken: nextToken(prefix: "access"),
      refreshToken: refreshToken
    )
  }

  public func refresh(refreshToken: String) async throws -> TokenPair {
    if let forcedError {
      throw forcedError
    }

    guard let phone = phoneByRefreshToken[refreshToken], let storedUser = usersByPhone[phone] else {
      throw AuthRepositoryError.backend(statusCode: 401, code: .invalidRefresh, issues: [])
    }

    let newRefreshToken = nextToken(prefix: "refresh")
    phoneByRefreshToken.removeValue(forKey: refreshToken)
    usersByPhone[phone] = StoredUser(
      user: storedUser.user,
      password: storedUser.password,
      refreshToken: newRefreshToken
    )
    phoneByRefreshToken[newRefreshToken] = phone

    return TokenPair(accessToken: nextToken(prefix: "access"), refreshToken: newRefreshToken)
  }

  func nextToken(prefix: String) -> String {
    tokenCounter += 1
    return "\(prefix)-\(tokenCounter)"
  }
}
