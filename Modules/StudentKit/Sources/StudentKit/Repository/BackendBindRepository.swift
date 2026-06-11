import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No cache by design (spec 031 §9): bind state must be live — a stale
/// "pending" would hide an acceptance, and the payload is one row.
public actor BackendBindRepository: BindRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func submitBindRequest(code: String, displayName: String) async throws -> BindRequest {
    let token = try await session.accessToken()
    do {
      let dto = try await api.createBindRequest(
        CreateBindRequestRequestDTO(code: code, displayName: displayName),
        accessToken: token
      )
      return dto.toDomain()
    } catch {
      throw Self.mapped(error)
    }
  }

  public func myBindRequest() async throws -> BindRequest? {
    let token = try await session.accessToken()
    return try await api.myBindRequest(accessToken: token).bindRequest?.toDomain()
  }

  public func cancelBindRequest(id: UUID) async throws {
    let token = try await session.accessToken()
    do {
      try await api.cancelBindRequest(id: id, accessToken: token)
    } catch {
      throw Self.mapped(error)
    }
  }

  /// Envelope machine codes → typed errors; everything else passes through
  /// (treated as a transport failure by the UI).
  private static func mapped(_ error: any Error) -> any Error {
    BindRequestError(machineCode: BackendErrorEnvelope.machineCode(from: error)) ?? error
  }
}
