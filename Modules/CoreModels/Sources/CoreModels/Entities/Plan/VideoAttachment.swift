import Foundation

/// A set-recording video the student attached to a logged set (spec 027).
///
/// V0.1 wiring note: the backend attachment pipeline (backend spec 004) stores
/// generic attachments with no set-log association column, so this entity is
/// the *local* source of truth for the setLog ↔ attachment link. It persists
/// to a JSON file on device; `remoteAttachmentID` points at the backend
/// `attachments` row once the upload has been initiated.
public struct VideoAttachment: Codable, Hashable, Sendable, Identifiable {
  /// Local upload lifecycle. Pending/uploading records remain visually neutral
  /// while background tasks and persisted retry state advance the pipeline.
  public enum Status: String, Codable, Sendable {
    /// Export finished (or queued); upload has not reached the backend yet.
    case pending
    /// Parts are being PUT to OSS right now.
    case uploading
    /// Backend confirmed `complete`; the attachment is `ready` server-side.
    case uploaded
    /// The retry time box ended or a deterministic failure occurred.
    case failed
  }

  public let id: UUID
  /// Local association to `StudentSetLog.id` — see the wiring note above.
  public let setLogID: UUID
  public let studentID: UUID
  /// Backend `attachments.id`, set once `POST /uploads/initiate` succeeded.
  public var remoteAttachmentID: UUID?
  public var status: Status
  public let contentType: String
  public let durationSeconds: Double
  public var sizeBytes: Int64
  /// File name of the exported H.264 video inside the local upload directory.
  public var localFileName: String?
  public let recordedAt: Date
  /// Training day that owns the set log. Unlike `recordedAt`, this remains
  /// correct when a student attaches video while editing a historical day.
  public let trainingDate: Date
  public var uploadedAt: Date?
  /// Number of multipart chunks in the current remote upload session.
  public var uploadPartCount: Int
  /// Presigned targets for the current remote upload session. Keeping these
  /// locally lets a relaunched app submit any part that had not reached the
  /// background session before termination.
  public var uploadPartTargets: [VideoUploadPartTarget]
  /// Successfully uploaded part ETags, persisted after every background task.
  public var uploadedParts: [VideoUploadedPart]
  /// Number of whole-pipeline retries since `firstUploadFailureAt`.
  public var uploadRetryCount: Int
  /// Starts the fixed retry time box and survives app restarts.
  public var firstUploadFailureAt: Date?

  public init(
    id: UUID,
    setLogID: UUID,
    studentID: UUID,
    remoteAttachmentID: UUID? = nil,
    status: Status,
    contentType: String,
    durationSeconds: Double,
    sizeBytes: Int64,
    localFileName: String? = nil,
    recordedAt: Date,
    trainingDate: Date? = nil,
    uploadedAt: Date? = nil,
    uploadPartCount: Int = 0,
    uploadPartTargets: [VideoUploadPartTarget] = [],
    uploadedParts: [VideoUploadedPart] = [],
    uploadRetryCount: Int = 0,
    firstUploadFailureAt: Date? = nil
  ) {
    self.id = id
    self.setLogID = setLogID
    self.studentID = studentID
    self.remoteAttachmentID = remoteAttachmentID
    self.status = status
    self.contentType = contentType
    self.durationSeconds = durationSeconds
    self.sizeBytes = sizeBytes
    self.localFileName = localFileName
    self.recordedAt = recordedAt
    self.trainingDate = trainingDate ?? recordedAt
    self.uploadedAt = uploadedAt
    self.uploadPartCount = uploadPartCount
    self.uploadPartTargets = uploadPartTargets
    self.uploadedParts = uploadedParts
    self.uploadRetryCount = uploadRetryCount
    self.firstUploadFailureAt = firstUploadFailureAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case setLogID
    case studentID
    case remoteAttachmentID
    case status
    case contentType
    case durationSeconds
    case sizeBytes
    case localFileName
    case recordedAt
    case trainingDate
    case uploadedAt
    case uploadPartCount
    case uploadPartTargets
    case uploadedParts
    case uploadRetryCount
    case firstUploadFailureAt
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    setLogID = try container.decode(UUID.self, forKey: .setLogID)
    studentID = try container.decode(UUID.self, forKey: .studentID)
    remoteAttachmentID = try container.decodeIfPresent(UUID.self, forKey: .remoteAttachmentID)
    status = try container.decode(Status.self, forKey: .status)
    contentType = try container.decode(String.self, forKey: .contentType)
    durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
    sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
    localFileName = try container.decodeIfPresent(String.self, forKey: .localFileName)
    recordedAt = try container.decode(Date.self, forKey: .recordedAt)
    trainingDate = try container.decodeIfPresent(Date.self, forKey: .trainingDate) ?? recordedAt
    uploadedAt = try container.decodeIfPresent(Date.self, forKey: .uploadedAt)
    uploadPartCount = try container.decodeIfPresent(Int.self, forKey: .uploadPartCount) ?? 0
    uploadPartTargets =
      try container.decodeIfPresent([VideoUploadPartTarget].self, forKey: .uploadPartTargets) ?? []
    uploadedParts =
      try container.decodeIfPresent([VideoUploadedPart].self, forKey: .uploadedParts) ?? []
    uploadRetryCount = try container.decodeIfPresent(Int.self, forKey: .uploadRetryCount) ?? 0
    firstUploadFailureAt = try container.decodeIfPresent(Date.self, forKey: .firstUploadFailureAt)
  }
}

public struct VideoUploadPartTarget: Codable, Hashable, Sendable {
  public let partNumber: Int
  public let url: URL

  public init(partNumber: Int, url: URL) {
    self.partNumber = partNumber
    self.url = url
  }
}

public struct VideoUploadedPart: Codable, Hashable, Sendable {
  public let partNumber: Int
  public let etag: String

  public init(partNumber: Int, etag: String) {
    self.partNumber = partNumber
    self.etag = etag
  }
}
