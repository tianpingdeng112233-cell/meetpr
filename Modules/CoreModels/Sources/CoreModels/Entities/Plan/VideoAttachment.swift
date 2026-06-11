import Foundation

/// A set-recording video the student attached to a logged set (spec 027).
///
/// V0.1 wiring note: the backend attachment pipeline (backend spec 004) stores
/// generic attachments with no set-log association column, so this entity is
/// the *local* source of truth for the setLog ↔ attachment link. It persists
/// to a JSON file on device; `remoteAttachmentID` points at the backend
/// `attachments` row once the upload has been initiated.
public struct VideoAttachment: Codable, Hashable, Sendable, Identifiable {
  /// Local upload lifecycle. V0.1 has no background-session resume: an upload
  /// interrupted by an app kill is marked `failed` on next launch and can be
  /// retried from scratch (new backend attachment row).
  public enum Status: String, Codable, Sendable {
    /// Export finished (or queued); upload has not reached the backend yet.
    case pending
    /// Parts are being PUT to OSS right now.
    case uploading
    /// Backend confirmed `complete`; the attachment is `ready` server-side.
    case uploaded
    /// Upload broke (network, app kill, server reject); retryable.
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
  public var uploadedAt: Date?

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
    uploadedAt: Date? = nil
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
    self.uploadedAt = uploadedAt
  }
}
