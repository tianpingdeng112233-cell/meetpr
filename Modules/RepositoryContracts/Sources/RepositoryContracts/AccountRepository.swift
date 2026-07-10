import Foundation

public enum AccountRepositoryError: Error, Equatable {
  /// PUT /me/password 403 — the old password failed verification.
  case passwordMismatch
}

/// Account deletion and password rotation (spec 048 / backend spec 011).
public protocol AccountRepository: Sendable {
  /// DELETE /me. The caller owns local cleanup after server success.
  func deleteAccount() async throws

  /// PUT /me/password. A wrong old password throws `passwordMismatch`.
  func changePassword(old: String, new: String) async throws
}
