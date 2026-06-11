import CoreModels
import Foundation

/// Store for set-recording video attachments (spec 027).
///
/// The backend attachment pipeline (backend spec 004) is association-agnostic,
/// so implementations keep the setLog ↔ attachment mapping on device (JSON
/// file, LocalE1RMRepository precedent). Coach-side cross-device consumption
/// needs a server-side association and is deferred (spec 029 follow-up).
public protocol VideoAttachmentRepository: Sendable {
  /// Inserts or replaces by `attachment.id`.
  func save(_ attachment: VideoAttachment) async throws
  func fetch(id: UUID) async throws -> VideoAttachment?
  func fetch(setLogID: UUID) async throws -> [VideoAttachment]
  func fetchAll(studentID: UUID) async throws -> [VideoAttachment]
  func delete(id: UUID) async throws
  /// Short-lived presigned playback URL (`GET /uploads/:id/url`). Returns nil
  /// when the attachment has not finished uploading or the implementation has
  /// no backend (in-memory / demo).
  func playbackURL(for attachment: VideoAttachment) async throws -> URL?
}
