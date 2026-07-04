import Foundation

public enum AccountRepositoryError: Error, Equatable {
  /// PUT /me/password 403 — the old password failed verification.
  case passwordMismatch
}

/// 账号台账 (spec 048 / backend 011): deletion and password rotation.
public protocol AccountRepository: Sendable {
  /// DELETE /me — permanently removes the account and every table row it
  /// cascades to. The caller is responsible for local cleanup (logout).
  func deleteAccount() async throws
  /// PUT /me/password. Throws `AccountRepositoryError.passwordMismatch`
  /// when the old password is wrong; other failures pass through.
  func changePassword(old: String, new: String) async throws
}
