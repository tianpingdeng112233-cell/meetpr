import Foundation
import Networking

/// Production `VideoUploadService`: backend `/uploads/*` via `APIClient` and
/// part PUTs straight to OSS via `OSSPartUploader` (presigned URLs live on
/// the OSS domain, outside the API base URL).
public struct BackendVideoUploadService: VideoUploadService {
  private let api: APIClient
  private let session: any SessionStateReader
  private let partUploader: OSSPartUploader

  public init(
    api: APIClient,
    session: any SessionStateReader,
    partUploader: OSSPartUploader = OSSPartUploader()
  ) {
    self.api = api
    self.session = session
    self.partUploader = partUploader
  }

  public func initiate(
    _ request: InitiateUploadRequestDTO
  ) async throws -> InitiateUploadResponseDTO {
    try await api.initiateUpload(request, accessToken: session.accessToken())
  }

  public func uploadPart(to url: URL, data: Data) async throws -> String {
    try await partUploader.uploadPart(to: url, data: data)
  }

  public func complete(
    attachmentID: UUID,
    parts: [UploadPartETagDTO]
  ) async throws -> AttachmentDTO {
    try await api.completeUpload(
      attachmentID: attachmentID,
      parts: parts,
      accessToken: session.accessToken()
    )
  }

  public func abort(attachmentID: UUID) async throws {
    try await api.abortUpload(attachmentID: attachmentID, accessToken: session.accessToken())
  }

  public func delete(attachmentID: UUID) async throws {
    let token = try await session.accessToken()
    do {
      try await api.deleteUpload(attachmentID: attachmentID, accessToken: token)
    } catch APIError.httpStatus(409, let data) where Self.isDeletingState(data) {
      // If a prior DELETE was interrupted after claiming the durable state,
      // reconcile completes the same deletion rather than leaving a retry loop.
      try await api.reconcileUpload(attachmentID: attachmentID, accessToken: token)
    } catch APIError.httpStatus(404, let data) where Self.isAttachmentAlreadyGone(data) {
      // The requested object was already removed, but the app did not get the
      // earlier response. It is safe to clear the matching local record.
    }
  }

  private static func isDeletingState(_ data: Data) -> Bool {
    let body = try? JSONDecoder().decode(UploadErrorBody.self, from: data)
    return body?.error == "UPLOAD_INVALID_STATE" && body?.status == "deleting"
  }

  private static func isAttachmentAlreadyGone(_ data: Data) -> Bool {
    let body = try? JSONDecoder().decode(UploadErrorBody.self, from: data)
    return body?.error == "ATTACHMENT_NOT_FOUND"
  }

  private struct UploadErrorBody: Decodable {
    let error: String
    let status: String?
  }
}

/// Offline stand-in for demo builds and previews: every call succeeds
/// instantly without touching the network.
public struct LoopbackVideoUploadService: VideoUploadService {
  public init() {}

  public func initiate(
    _ request: InitiateUploadRequestDTO
  ) async throws -> InitiateUploadResponseDTO {
    let partURLs = (1...max(request.partCount, 1)).map { partNumber in
      UploadPartURLDTO(partNumber: partNumber, url: "https://demo.invalid/parts/\(partNumber)")
    }
    return InitiateUploadResponseDTO(
      attachmentID: UUID(),
      uploadID: "demo-upload",
      partURLs: partURLs
    )
  }

  public func uploadPart(to url: URL, data: Data) async throws -> String {
    "demo-etag"
  }

  public func complete(
    attachmentID: UUID,
    parts: [UploadPartETagDTO]
  ) async throws -> AttachmentDTO {
    AttachmentDTO(
      id: attachmentID,
      ownerID: UUID(),
      kind: .setVideo,
      ossKey: "attachments/demo/\(attachmentID.uuidString).mp4",
      contentType: "video/mp4",
      sizeBytes: Int64(parts.count),
      filename: nil,
      status: .ready,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  public func abort(attachmentID: UUID) async throws {}

  public func delete(attachmentID: UUID) async throws {}
}
