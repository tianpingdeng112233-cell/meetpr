import Foundation

// Wire shapes for the backend attachment-upload pipeline (backend spec 004,
// `/uploads/*`). All wire keys are snake_case; MeetPRCodec's key strategies
// convert to/from the camelCase coding keys below.

public enum AttachmentKindDTO: String, Codable, Equatable, Sendable {
  case setVideo = "set_video"
  case onboardingVideo = "onboarding_video"
  case onboardingDoc = "onboarding_doc"
  case chatImage = "chat_image"
}

public enum AttachmentStatusDTO: String, Codable, Equatable, Sendable {
  case uploading
  case ready
  case aborted
}

public struct InitiateUploadRequestDTO: Codable, Equatable, Sendable {
  public let kind: AttachmentKindDTO
  public let contentType: String
  public let sizeBytes: Int64
  public let partCount: Int
  /// Optional display name (human-facing only since set_log_id exists).
  public let filename: String?
  /// Server-side association for set videos (backend spec 007): the coach
  /// video wall resolves through this, so it must be the backend's canonical
  /// set-log id, never a locally generated one.
  public let setLogID: UUID?

  public init(
    kind: AttachmentKindDTO,
    contentType: String,
    sizeBytes: Int64,
    partCount: Int,
    filename: String? = nil,
    setLogID: UUID? = nil
  ) {
    self.kind = kind
    self.contentType = contentType
    self.sizeBytes = sizeBytes
    self.partCount = partCount
    self.filename = filename
    self.setLogID = setLogID
  }
}

public struct UploadPartURLDTO: Codable, Equatable, Sendable {
  public let partNumber: Int
  public let url: String

  public init(partNumber: Int, url: String) {
    self.partNumber = partNumber
    self.url = url
  }
}

public struct InitiateUploadResponseDTO: Codable, Equatable, Sendable {
  public let attachmentID: UUID
  public let uploadID: String
  public let partURLs: [UploadPartURLDTO]

  public init(attachmentID: UUID, uploadID: String, partURLs: [UploadPartURLDTO]) {
    self.attachmentID = attachmentID
    self.uploadID = uploadID
    self.partURLs = partURLs
  }

  private enum CodingKeys: String, CodingKey {
    case attachmentID = "attachmentId"
    case uploadID = "uploadId"
    case partURLs = "partUrls"
  }
}

public struct UploadPartETagDTO: Codable, Equatable, Sendable {
  public let partNumber: Int
  public let etag: String

  public init(partNumber: Int, etag: String) {
    self.partNumber = partNumber
    self.etag = etag
  }
}

public struct CompleteUploadRequestDTO: Codable, Equatable, Sendable {
  public let parts: [UploadPartETagDTO]

  public init(parts: [UploadPartETagDTO]) {
    self.parts = parts
  }
}

public struct AttachmentDTO: Codable, Equatable, Sendable {
  public let id: UUID
  public let ownerID: UUID
  public let kind: AttachmentKindDTO
  public let ossKey: String
  public let contentType: String
  public let sizeBytes: Int64
  public let filename: String?
  public let status: AttachmentStatusDTO
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    ownerID: UUID,
    kind: AttachmentKindDTO,
    ossKey: String,
    contentType: String,
    sizeBytes: Int64,
    filename: String?,
    status: AttachmentStatusDTO,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.ownerID = ownerID
    self.kind = kind
    self.ossKey = ossKey
    self.contentType = contentType
    self.sizeBytes = sizeBytes
    self.filename = filename
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case ownerID = "ownerId"
    case kind
    case ossKey
    case contentType
    case sizeBytes
    case filename
    case status
    case createdAt
    case updatedAt
  }
}

public struct AttachmentURLResponseDTO: Codable, Equatable, Sendable {
  public let url: String
  public let expiresIn: Int

  public init(url: String, expiresIn: Int) {
    self.url = url
    self.expiresIn = expiresIn
  }
}

/// `POST /uploads/:id/abort` takes a strictly empty JSON object body.
public struct EmptyWireBody: Codable, Equatable, Sendable {
  public init() {}
}
