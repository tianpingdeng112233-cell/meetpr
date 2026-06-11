import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// No cache by design (spec 031 §9): the code list is tiny and mutations
/// must read back the backend's truth (e.g. personal regeneration revoking
/// the old code server-side).
public actor BackendInviteCodeRepository: InviteCodeRepository {
  private let api: APIClient
  private let session: any SessionStateReader

  public init(api: APIClient, session: any SessionStateReader) {
    self.api = api
    self.session = session
  }

  public func createCode(
    type: InviteCodeType,
    label: String?,
    expiresInDays: Int?
  ) async throws -> InviteCode {
    let token = try await session.accessToken()
    let dto = try await api.createInviteCode(
      CreateInviteCodeRequestDTO(type: type, label: label, expiresInDays: expiresInDays),
      accessToken: token
    )
    return dto.toDomain()
  }

  public func listCodes() async throws -> [InviteCode] {
    let token = try await session.accessToken()
    return try await api.inviteCodes(accessToken: token).inviteCodes.map { $0.toDomain() }
  }

  public func revokeCode(id: UUID) async throws {
    let token = try await session.accessToken()
    do {
      try await api.revokeInviteCode(id: id, accessToken: token)
    } catch {
      throw BindRequestError(machineCode: BackendErrorEnvelope.machineCode(from: error)) ?? error
    }
  }
}
