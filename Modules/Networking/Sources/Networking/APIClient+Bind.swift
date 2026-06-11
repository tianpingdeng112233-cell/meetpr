import Foundation

// Invite-code + bind-request endpoints (spec 031; backend spec 005 §A/§B).

extension APIClient {
  // MARK: - Coach side

  /// POST /coach/invite-codes → 201
  public func createInviteCode(
    _ body: CreateInviteCodeRequestDTO,
    accessToken: String
  ) async throws -> InviteCodeDTO {
    try await post(path: "/coach/invite-codes", body: body, accessToken: accessToken)
  }

  /// GET /coach/invite-codes → 200
  public func inviteCodes(accessToken: String) async throws -> InviteCodesResponseDTO {
    try await get(path: "/coach/invite-codes", accessToken: accessToken)
  }

  /// DELETE /coach/invite-codes/:id → 204 (revoke, idempotent)
  public func revokeInviteCode(id: UUID, accessToken: String) async throws {
    try await deleteNoContent(
      path: "/coach/invite-codes/\(id.uuidString)",
      accessToken: accessToken
    )
  }

  // MARK: - Student side

  /// POST /bind-requests → 201
  public func createBindRequest(
    _ body: CreateBindRequestRequestDTO,
    accessToken: String
  ) async throws -> BindRequestDTO {
    try await post(path: "/bind-requests", body: body, accessToken: accessToken)
  }

  /// GET /bind-requests/mine → 200
  public func myBindRequest(accessToken: String) async throws -> MyBindRequestResponseDTO {
    try await get(path: "/bind-requests/mine", accessToken: accessToken)
  }

  /// DELETE /bind-requests/:id → 204 (cancel own pending request)
  public func cancelBindRequest(id: UUID, accessToken: String) async throws {
    try await deleteNoContent(path: "/bind-requests/\(id.uuidString)", accessToken: accessToken)
  }
}
