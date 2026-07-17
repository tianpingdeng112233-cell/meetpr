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
  public let phone: String
  public let role: UserRole
  public let createdAt: Date

  public init(id: UUID, phone: String, role: UserRole, createdAt: Date) {
    self.id = id
    self.phone = phone
    self.role = role
    self.createdAt = createdAt
  }

  public func toUser() throws -> User {
    return User(
      id: id,
      phone: phone,
      name: nil,
      unitSystem: .metric,
      role: role,
      createdAt: createdAt,
      updatedAt: createdAt
    )
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
