import Foundation
import Networking

/// Production `VideoUploadService`: backend `/uploads/*` via `APIClient` and
/// part PUTs straight to OSS via `OSSPartUploader` (presigned URLs live on
/// the OSS domain, outside the API base URL).
public struct BackendVideoUploadService: VideoUploadService {
  private let api: APIClient
  private let session: any SessionStateReader
  private let partUploader: BackgroundVideoPartUploader

  public var backgroundEvents: AsyncStream<BackgroundVideoUploadEvent> {
    partUploader.events
  }

  public init(
    api: APIClient,
    session: any SessionStateReader
  ) {
    self.api = api
    self.session = session
    self.partUploader = BackgroundVideoPartUploader()
  }

  public func initiate(
    _ request: InitiateUploadRequestDTO
  ) async throws -> InitiateUploadResponseDTO {
    try await api.initiateUpload(request, accessToken: session.accessToken())
  }

  public func uploadPart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws -> String {
    try await partUploader.upload(to: url, from: fileURL, identifier: identifier)
  }

  public func schedulePart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws {
    try partUploader.schedule(to: url, from: fileURL, identifier: identifier)
  }

  public func complete(
    attachmentID: UUID,
    parts: [UploadPartETagDTO]
  ) async throws -> AttachmentDTO {
    do {
      return try await api.completeUpload(
        attachmentID: attachmentID,
        parts: parts,
        accessToken: session.accessToken()
      )
    } catch let error as APIError {
      guard case .httpStatus(409, _) = error else { throw error }
      throw VideoUploadCompleteConflict(apiError: error)
    }
  }

  public func abort(attachmentID: UUID) async throws {
    try await api.abortUpload(attachmentID: attachmentID, accessToken: session.accessToken())
  }

  public func isBackgroundWakeActive() async -> Bool {
    BackgroundUploadCompletionRegistry.shared.hasPendingHandler(
      identifier: BackgroundVideoPartUploader.sessionIdentifier
    )
  }

  public func pendingPartNumbers(recordID: UUID, generation: Int) async -> Set<Int> {
    await partUploader.pendingParts(recordID: recordID, generation: generation)
  }

  public func cancelLegacyParts(recordID: UUID) async -> Bool {
    await partUploader.cancelLegacyParts(recordID: recordID)
  }

  public func cancelParts(recordID: UUID) async {
    await partUploader.cancelParts(recordID: recordID)
  }

  public func claimBackgroundCancellation() async -> BackgroundUploadCancellationClaim? {
    partUploader.claimCancellationIfBackgroundWakeInactive()
  }

  public func cancelParts(recordID: UUID, claim: BackgroundUploadCancellationClaim) async {
    await partUploader.cancelParts(recordID: recordID, claim: claim)
  }

  public func releaseBackgroundCancellationClaim(
    _ claim: BackgroundUploadCancellationClaim
  ) async {
    partUploader.releaseCancellationClaim(claim)
  }
}

/// Offline stand-in for demo builds and previews: every call succeeds
/// instantly without touching the network.
public struct LoopbackVideoUploadService: VideoUploadService {
  public init() {}

  public var backgroundEvents: AsyncStream<BackgroundVideoUploadEvent> {
    AsyncStream { continuation in continuation.finish() }
  }

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

  public func uploadPart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws -> String {
    _ = try Data(contentsOf: fileURL)
    return "demo-etag"
  }

  public func schedulePart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws {
    _ = try Data(contentsOf: fileURL)
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

  public func isBackgroundWakeActive() async -> Bool { false }

  public func pendingPartNumbers(recordID: UUID, generation: Int) async -> Set<Int> { [] }
  public func cancelLegacyParts(recordID: UUID) async -> Bool { false }
  public func cancelParts(recordID: UUID) async {}
  public func claimBackgroundCancellation() async -> BackgroundUploadCancellationClaim? {
    BackgroundUploadCancellationClaim(sessionIdentifier: "loopback-video-upload")
  }
  public func cancelParts(recordID: UUID, claim: BackgroundUploadCancellationClaim) async {}
  public func releaseBackgroundCancellationClaim(
    _ claim: BackgroundUploadCancellationClaim
  ) async {}
}
