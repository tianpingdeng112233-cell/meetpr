import CoreModels
import Foundation
import Networking

@testable import AppShell

enum AuthTestSupport {
  static let createdAtString = "2026-04-29T09:44:22Z"

  static func user(role: UserRole = .coach, phone: String = "+8613800000001") -> User {
    let createdAt = Date(timeIntervalSince1970: 1_777_448_662)
    return User(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000011") ?? UUID(),
      phone: phone,
      name: nil,
      unitSystem: .metric,
      role: role,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  static func authResultData(
    phone: String = "+8613800000001",
    role: UserRole = .coach,
    accessToken: String = "access-token",
    refreshToken: String = "refresh-token"
  ) throws -> Data {
    let user = AuthUserDTO(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000011") ?? UUID(),
      phone: phone,
      role: role,
      createdAt: createdAtString
    )
    let response = AuthResultDTO(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken
    )
    return try JSONEncoder().encode(response)
  }

  static func refreshData(
    accessToken: String = "new-access-token",
    refreshToken: String = "new-refresh-token"
  ) throws -> Data {
    let response = AuthRefreshResponseDTO(accessToken: accessToken, refreshToken: refreshToken)
    return try JSONEncoder().encode(response)
  }

  static func errorData(
    code: String,
    issues: [AuthValidationIssueDTO]? = nil
  ) throws -> Data {
    let envelope = AuthErrorEnvelopeDTO(error: code, issues: issues)
    return try JSONEncoder().encode(envelope)
  }
}

actor RequestCapture {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }

  func body() -> Data? {
    capturedRequest?.httpBody
  }
}
