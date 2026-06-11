import Foundation

// Coach receive-queue endpoints (spec 033; backend spec 005 §endpoint B).

extension APIClient {
  /// GET /coach/bind-requests → 200 (pending only, submitted_at ASC).
  public func coachBindRequests(accessToken: String) async throws -> CoachBindRequestsResponseDTO {
    try await get(path: "/coach/bind-requests", accessToken: accessToken)
  }

  /// POST /coach/bind-requests/:id/accept → 200. 404 BIND_REQUEST_NOT_FOUND /
  /// 409 BIND_REQUEST_EXPIRED / 409 BIND_REQUEST_NOT_PENDING /
  /// 409 BIND_ALREADY_BOUND.
  public func acceptBindRequest(
    id: UUID,
    _ body: AcceptBindRequestRequestDTO,
    accessToken: String
  ) async throws -> AcceptBindRequestResponseDTO {
    try await post(
      path: "/coach/bind-requests/\(id.uuidString)/accept",
      body: body,
      accessToken: accessToken
    )
  }

  /// POST /coach/bind-requests/:id/reject → 200. Body is the `.strict()`
  /// empty object — any key is a 400. Same error codes as accept.
  public func rejectBindRequest(
    id: UUID,
    accessToken: String
  ) async throws -> RejectBindRequestResponseDTO {
    try await post(
      path: "/coach/bind-requests/\(id.uuidString)/reject",
      body: EmptyObjectBodyDTO(),
      accessToken: accessToken
    )
  }
}
