import CoreModels
import Foundation
import Networking

public enum VideoUploadError: Error, Equatable, Sendable {
  case durationExceedsLimit(seconds: Double, maxSeconds: Double)
  case exportFailed(String)
  case emptyFile
  case fileUnreadable
  case localFileMissing
  case invalidPartURL(partNumber: Int)
  case partURLCountMismatch(expected: Int, received: Int)
  /// `POST /uploads/:id/complete` answered 409 — the backend attachment
  /// already left the `uploading` state, so this upload session is dead.
  /// Retry goes through a fresh initiate, never through abort.
  case completeConflict
}

/// Tuning knobs for `VideoUploadManager` (spec 027 §chunk size + retry,
/// trimmed to the V0.1 foreground pipeline).
public struct VideoUploadConfiguration: Sendable {
  /// OSS multipart chunk size; 5 MB balances part count vs. re-upload cost.
  public var partSizeBytes: Int
  public var maxDurationSeconds: Double
  /// Retries per part after the first failed attempt.
  public var partRetryCount: Int
  public var maxConcurrentParts: Int
  public var partRetryDelay: Duration

  public init(
    partSizeBytes: Int = 5 * 1024 * 1024,
    maxDurationSeconds: Double = 120,
    partRetryCount: Int = 2,
    maxConcurrentParts: Int = 3,
    partRetryDelay: Duration = .seconds(1)
  ) {
    self.partSizeBytes = partSizeBytes
    self.maxDurationSeconds = maxDurationSeconds
    self.partRetryCount = partRetryCount
    self.maxConcurrentParts = maxConcurrentParts
    self.partRetryDelay = partRetryDelay
  }

  public static let `default` = VideoUploadConfiguration()
}

/// Status pushes from `VideoUploadManager` to UI observers.
public enum VideoUploadEvent: Equatable, Sendable {
  /// `progress` is 0...1 across the part uploads; nil when unchanged.
  case updated(VideoAttachment, progress: Double?)
  case removed(setLogID: UUID, attachmentID: UUID)
}

/// Abstraction over AVFoundation export so the upload state machine is unit
/// testable without rendering video (spec 027 tests).
public protocol VideoExporting: Sendable {
  func durationSeconds(of sourceURL: URL) async throws -> Double
  /// Prepares an H.264 MP4, remuxing eligible sources and transcoding others.
  func export(from sourceURL: URL, to destinationURL: URL) async throws
}

/// Wire boundary of the upload pipeline: backend `/uploads/*` endpoints plus
/// the direct-to-OSS part PUT. Mocked wholesale in unit tests.
public protocol VideoUploadService: Sendable {
  func initiate(_ request: InitiateUploadRequestDTO) async throws -> InitiateUploadResponseDTO
  /// PUTs one chunk to a presigned OSS URL and returns its unquoted ETag.
  func uploadPart(to url: URL, data: Data) async throws -> String
  func complete(attachmentID: UUID, parts: [UploadPartETagDTO]) async throws -> AttachmentDTO
  func abort(attachmentID: UUID) async throws
}
