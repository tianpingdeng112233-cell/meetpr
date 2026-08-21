import CoreModels
import Foundation

public struct AuthRegisterRequestDTO: Codable, Equatable, Sendable {
  public let phone: String
  public let password: String
  public let role: UserRole

  public init(phone: String, password: String, role: UserRole) {
    self.phone = phone
    self.password = password
    self.role = role
  }
}

public struct AuthLoginRequestDTO: Codable, Equatable, Sendable {
  public let phone: String
  public let password: String

  public init(phone: String, password: String) {
    self.phone = phone
    self.password = password
  }
}

/// Wire contract: `MeetPRCodec.encoder` (`.convertToSnakeCase`) serializes this as
/// `{"refresh_token": …}` — the canonical key for every backend request schema.
/// The backend also tolerates `refreshToken` (PR #76), but snake_case is what we pin
/// in `AuthRefreshRequestEncodingTests`; changing the encoder or this property name
/// silently breaks token refresh for every shipped client (2026-07-17 incident).
public struct AuthRefreshRequestDTO: Codable, Equatable, Sendable {
  public let refreshToken: String

  public init(refreshToken: String) {
    self.refreshToken = refreshToken
  }
}

public struct AuthUserDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let phone: String?
  public let email: String?
  public let role: UserRole
  public let createdAt: Date

  public init(
    id: UUID,
    phone: String?,
    email: String? = nil,
    role: UserRole,
    createdAt: Date
  ) {
    self.id = id
    self.phone = phone
    self.email = email
    self.role = role
    self.createdAt = createdAt
  }

  public func toUser() throws -> User {
    return User(
      id: id,
      // `CoreModels.User` predates email/OIDC identities and still requires a
      // string in its legacy `phone` slot. Keep CN exact, while giving Global
      // email accounts a stable cached identifier until that domain migration
      // gets its own spec. Apple can legitimately return neither value.
      phone: phone ?? email ?? "",
      name: nil,
      unitSystem: .metric,
      role: role,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }
}

public struct AuthChallengeDTO: Codable, Equatable, Sendable {
  public let nonce: String
  public let expiresAt: Date

  public init(nonce: String, expiresAt: Date) {
    self.nonce = nonce
    self.expiresAt = expiresAt
  }
}

public struct AppleAuthRequestDTO: Codable, Equatable, Sendable {
  public let identityToken: String
  public let nonce: String
  public let role: UserRole
  public let authorizationCode: String?
  public let timezone: String?

  public init(
    identityToken: String,
    nonce: String,
    role: UserRole,
    authorizationCode: String? = nil,
    timezone: String? = nil
  ) {
    self.identityToken = identityToken
    self.nonce = nonce
    self.role = role
    self.authorizationCode = authorizationCode
    self.timezone = timezone
  }
}

public struct GoogleAuthRequestDTO: Codable, Equatable, Sendable {
  public let idToken: String
  public let nonce: String?
  public let role: UserRole
  public let timezone: String?

  public init(
    idToken: String,
    nonce: String? = nil,
    role: UserRole,
    timezone: String? = nil
  ) {
    self.idToken = idToken
    self.nonce = nonce
    self.role = role
    self.timezone = timezone
  }
}

public struct EmailRegisterRequestDTO: Codable, Equatable, Sendable {
  public let email: String
  public let password: String
  public let role: UserRole
  public let timezone: String?

  public init(email: String, password: String, role: UserRole, timezone: String? = nil) {
    self.email = email
    self.password = password
    self.role = role
    self.timezone = timezone
  }
}

public struct EmailLoginRequestDTO: Codable, Equatable, Sendable {
  public let email: String
  public let password: String

  public init(email: String, password: String) {
    self.email = email
    self.password = password
  }
}

public struct EmailForgotRequestDTO: Codable, Equatable, Sendable {
  public let email: String

  public init(email: String) {
    self.email = email
  }
}

public struct EmailResetRequestDTO: Codable, Equatable, Sendable {
  public let email: String
  public let code: String
  public let newPassword: String

  public init(email: String, code: String, newPassword: String) {
    self.email = email
    self.code = code
    self.newPassword = newPassword
  }
}

public struct TimezoneUpdateRequestDTO: Codable, Equatable, Sendable {
  public let timezone: String

  public init(timezone: String) {
    self.timezone = timezone
  }
}

public struct AuthResultDTO: Codable, Equatable, Sendable {
  public let user: AuthUserDTO
  public let accessToken: String
  public let refreshToken: String

  public init(user: AuthUserDTO, accessToken: String, refreshToken: String) {
    self.user = user
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public struct AuthRefreshResponseDTO: Codable, Equatable, Sendable {
  public let accessToken: String
  public let refreshToken: String

  public init(accessToken: String, refreshToken: String) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public struct AuthValidationIssueDTO: Codable, Equatable, Sendable {
  public let path: [String]
  public let message: String

  public init(path: [String], message: String) {
    self.path = path
    self.message = message
  }
}

public struct AuthErrorEnvelopeDTO: Codable, Equatable, Sendable {
  public let error: String
  public let issues: [AuthValidationIssueDTO]?

  public init(error: String, issues: [AuthValidationIssueDTO]? = nil) {
    self.error = error
    self.issues = issues
  }
}
