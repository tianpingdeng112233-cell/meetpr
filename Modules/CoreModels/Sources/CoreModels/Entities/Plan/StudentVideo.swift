import Foundation

/// Coach-side metadata for one student set video (spec 029 second pass).
///
/// Mirrors a `GET /students/:id/videos` item: metadata only. Playback URLs
/// are exchanged per item at tap time (`GET /uploads/:id/url`) so a single
/// intercepted wall response never leaks a page of live URLs. Distinct from
/// `VideoAttachment`, the student-side *local* upload record — the coach has
/// no on-device files and reads the server-side wall instead.
public struct StudentVideo: Codable, Hashable, Sendable, Identifiable {
  /// Backend `attachments.id`; also the playback-URL exchange key.
  public let id: UUID
  /// Server-side set linkage; nil for unlinked uploads.
  public let setLogID: UUID?
  public let planExerciseID: UUID?
  public let contentType: String
  public let sizeBytes: Int64
  public let filename: String?
  public let createdAt: Date
  /// When the linked set was logged; nil for unlinked uploads.
  public let loggedAt: Date?

  public init(
    id: UUID,
    setLogID: UUID?,
    planExerciseID: UUID?,
    contentType: String,
    sizeBytes: Int64,
    filename: String?,
    createdAt: Date,
    loggedAt: Date?
  ) {
    self.id = id
    self.setLogID = setLogID
    self.planExerciseID = planExerciseID
    self.contentType = contentType
    self.sizeBytes = sizeBytes
    self.filename = filename
    self.createdAt = createdAt
    self.loggedAt = loggedAt
  }

  /// Grid grouping date: the training day when linked, upload time otherwise.
  public var displayDate: Date {
    loggedAt ?? createdAt
  }
}
