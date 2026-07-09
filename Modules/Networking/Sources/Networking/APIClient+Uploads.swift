import Foundation

// Typed endpoints for the backend attachment-upload pipeline (backend spec
// 004). Part PUTs do NOT go through these — presigned part URLs point at the
// OSS domain directly; see `OSSPartUploader`.
extension APIClient {
  /// `POST /uploads/initiate` → 201 with per-part presigned PUT URLs (1h TTL).
  public func initiateUpload(
    _ request: InitiateUploadRequestDTO,
    accessToken: String
  ) async throws -> InitiateUploadResponseDTO {
    try await post(path: "/uploads/initiate", body: request, accessToken: accessToken)
  }

  /// `POST /uploads/:id/complete` → 200 attachment metadata; 409 when the
  /// attachment already left the `uploading` state.
  public func completeUpload(
    attachmentID: UUID,
    parts: [UploadPartETagDTO],
    accessToken: String
  ) async throws -> AttachmentDTO {
    try await post(
      path: "/uploads/\(attachmentID.uuidString)/complete",
      body: CompleteUploadRequestDTO(parts: parts),
      accessToken: accessToken
    )
  }

  /// `POST /uploads/:id/abort` → 204 (idempotent re-abort).
  public func abortUpload(attachmentID: UUID, accessToken: String) async throws {
    try await postNoContent(
      path: "/uploads/\(attachmentID.uuidString)/abort",
      body: EmptyWireBody(),
      accessToken: accessToken
    )
  }

  /// Permanently removes an owner-owned attachment and its OSS object.
  /// The client only clears its local record after this succeeds.
  public func deleteUpload(attachmentID: UUID, accessToken: String) async throws {
    try await deleteNoContent(
      path: "/uploads/\(attachmentID.uuidString)",
      accessToken: accessToken
    )
  }

  /// Recovers a server-side deletion left in its durable deleting state by
  /// an interrupted process. Normal clients call this only after DELETE reports
  /// that exact state.
  public func reconcileUpload(attachmentID: UUID, accessToken: String) async throws {
    try await postNoContent(
      path: "/uploads/\(attachmentID.uuidString)/reconcile",
      body: EmptyWireBody(),
      accessToken: accessToken
    )
  }

  /// `GET /uploads/:id/url` → short-lived presigned GET URL for playback.
  public func attachmentURL(
    attachmentID: UUID,
    accessToken: String
  ) async throws -> AttachmentURLResponseDTO {
    try await get(
      path: "/uploads/\(attachmentID.uuidString)/url",
      accessToken: accessToken
    )
  }
}
