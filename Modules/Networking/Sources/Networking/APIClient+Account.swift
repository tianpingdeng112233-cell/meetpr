import Foundation

/// PUT /me/password body (backend spec 011 §2).
public struct ChangePasswordRequestDTO: Encodable, Equatable, Sendable {
  public let oldPassword: String
  public let newPassword: String

  public init(oldPassword: String, newPassword: String) {
    self.oldPassword = oldPassword
    self.newPassword = newPassword
  }
}

extension APIClient {
  /// DELETE /me (backend spec 011 §1) — 204, idempotent.
  public func deleteAccount(accessToken: String) async throws {
    try await deleteNoContent(path: "/me", accessToken: accessToken)
  }

  /// PUT /me/password — 204; 403 PASSWORD_MISMATCH on a wrong old password.
  public func changePassword(
    _ request: ChangePasswordRequestDTO,
    accessToken: String
  ) async throws {
    try await putNoContent(path: "/me/password", body: request, accessToken: accessToken)
  }
}
