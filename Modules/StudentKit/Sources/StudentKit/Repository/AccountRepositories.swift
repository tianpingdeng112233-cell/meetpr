import Foundation
import Networking
import RepositoryContracts

/// Live account ledger backed by DELETE /me and PUT /me/password.
public struct BackendAccountRepository: AccountRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func deleteAccount() async throws {
    let token = try await session.accessToken()
    try await api.deleteAccount(accessToken: token)
  }

  public func changePassword(old: String, new: String) async throws {
    let token = try await session.accessToken()
    do {
      try await api.changePassword(
        ChangePasswordRequestDTO(oldPassword: old, newPassword: new),
        accessToken: token
      )
    } catch {
      if BackendErrorEnvelope.machineCode(from: error) == "PASSWORD_MISMATCH" {
        throw AccountRepositoryError.passwordMismatch
      }
      throw error
    }
  }
}

/// Demo account store that records deletion and verifies a seeded password.
public actor InMemoryAccountRepository: AccountRepository {
  public private(set) var deleted = false
  private var password: String

  public init(password: String = "demo-pass-123") {
    self.password = password
  }

  public func deleteAccount() async throws {
    deleted = true
  }

  public func changePassword(old: String, new: String) async throws {
    guard old == password else {
      throw AccountRepositoryError.passwordMismatch
    }
    password = new
  }

  public func currentPassword() -> String {
    password
  }
}
