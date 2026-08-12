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
  /// The backend reports that this upload is irreversibly aborted or failed.
  case remoteTerminalState
}

enum VideoUploadRemoteStatus: String, Equatable, Sendable {
  case uploading
  case completing
  case ready
  case aborted
  case failed
}

struct VideoUploadCompleteConflict: Error, Equatable, Sendable {
  let status: VideoUploadRemoteStatus?

  init(status: VideoUploadRemoteStatus?) {
    self.status = status
  }

  init(apiError: APIError) {
    guard case .httpStatus(409, let data) = apiError,
      let payload = try? JSONDecoder().decode(CompleteUploadConflictPayload.self, from: data),
      payload.error == "UPLOAD_INVALID_STATE"
    else {
      status = nil
      return
    }
    status = VideoUploadRemoteStatus(rawValue: payload.status)
  }
}

private struct CompleteUploadConflictPayload: Decodable {
  let error: String
  let status: String
}

public struct BackgroundUploadCancellationClaim: Hashable, Sendable {
  public let sessionIdentifier: String
  public let id: UUID

  public init(sessionIdentifier: String, id: UUID = UUID()) {
    self.sessionIdentifier = sessionIdentifier
    self.id = id
  }
}

/// Tuning knobs for `VideoUploadManager` transport and validation.
public struct VideoUploadConfiguration: Sendable {
  /// OSS multipart chunk size; 5 MB balances part count vs. re-upload cost.
  public var partSizeBytes: Int
  public var maxDurationSeconds: Double
  public var maxConcurrentParts: Int

  public init(
    partSizeBytes: Int = 5 * 1024 * 1024,
    maxDurationSeconds: Double = 120,
    maxConcurrentParts: Int = 3
  ) {
    self.partSizeBytes = partSizeBytes
    self.maxDurationSeconds = maxDurationSeconds
    self.maxConcurrentParts = maxConcurrentParts
  }

  public static let `default` = VideoUploadConfiguration()
}

/// Status pushes from `VideoUploadManager` to UI observers.
public enum VideoUploadEvent: Equatable, Sendable {
  /// `progress` is 0...1 across the part uploads; nil when unchanged.
  case updated(VideoAttachment, progress: Double?)
  case removed(setLogID: UUID, attachmentID: UUID)
  case retryUnavailable(
    setLogID: UUID, attachmentID: UUID, reason: VideoRetryUnavailableReason)
}

/// Why a manual retry could not start; presentation copy is owned by the
/// view-model layer, not the upload actor.
public enum VideoRetryUnavailableReason: Equatable, Sendable {
  case sourceMissing
}

/// Abstraction over AVFoundation export so the upload state machine is unit
/// testable without rendering video (spec 027 tests).
public protocol VideoExporting: Sendable {
  func durationSeconds(of sourceURL: URL) async throws -> Double
  /// Re-encodes the source into a bitrate-capped, fast-start H.264 MP4
  /// sized for upload (long edge ≤1280, spec 065).
  func export(from sourceURL: URL, to destinationURL: URL) async throws
}

/// Wire boundary of the upload pipeline: backend `/uploads/*` endpoints plus
/// the direct-to-OSS part PUT. Mocked wholesale in unit tests.
public protocol VideoUploadService: Sendable {
  func initiate(_ request: InitiateUploadRequestDTO) async throws -> InitiateUploadResponseDTO
  /// Schedules one file-backed chunk PUT and returns its unquoted ETag.
  func uploadPart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws -> String
  /// Enqueues one file-backed PUT without awaiting its transfer. Used only
  /// while draining an iOS background-session wake window.
  func schedulePart(
    to url: URL,
    from fileURL: URL,
    identifier: VideoUploadPartIdentifier
  ) async throws
  func complete(attachmentID: UUID, parts: [UploadPartETagDTO]) async throws -> AttachmentDTO
  func abort(attachmentID: UUID) async throws
  var backgroundEvents: AsyncStream<BackgroundVideoUploadEvent> { get }
  func isBackgroundWakeActive() async -> Bool
  func pendingPartNumbers(recordID: UUID, generation: Int) async -> Set<Int>
  /// Cancels spec-069 two-segment tasks. Their callbacks have no generation
  /// and therefore cannot be safely adopted by a persisted spec-070 attempt.
  func cancelLegacyParts(recordID: UUID) async -> Bool
  func cancelParts(recordID: UUID) async
  /// Atomically claims manual cancellation only when no UIApplication
  /// background wake handler already owns the fixed URLSession identifier.
  func claimBackgroundCancellation() async -> BackgroundUploadCancellationClaim?
  /// Consumes a successful claim after the caller has advanced and persisted
  /// its generation, then enumerates and cancels the old URLSession tasks.
  func cancelParts(recordID: UUID, claim: BackgroundUploadCancellationClaim) async
  /// Releases a claim when generation persistence fails before cancellation.
  func releaseBackgroundCancellationClaim(_ claim: BackgroundUploadCancellationClaim) async
}
