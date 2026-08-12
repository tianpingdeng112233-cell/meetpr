import CoreModels
import Foundation
import Observation

/// UI-facing state for set-video attachments, keyed by set-log id. Owned by
/// TodayWorkoutView; SetEntrySheet renders per-set state from `rowStates`.
@MainActor
@Observable
public final class VideoAttachmentViewModel {
  public struct RowState: Equatable, Sendable {
    public var attachment: VideoAttachment
    /// 0...1 across part uploads; meaningful while `status == .uploading`.
    public var progress: Double
  }

  public static let consentDefaultsKey = "video_upload_consent_v1"

  let maxDurationSeconds: Double
  public private(set) var rowStates: [UUID: RowState] = [:]
  public private(set) var lastErrorMessage: String?
  public private(set) var retryErrorMessage: String?

  private let manager: VideoUploadManager
  private let consentDefaults: UserDefaults
  // nonisolated(unsafe) + ObservationIgnored: written only on the main actor;
  // deinit (nonisolated) just cancels it.
  @ObservationIgnored nonisolated(unsafe) private var observeTask: Task<Void, Never>?

  public init(manager: VideoUploadManager, consentDefaults: UserDefaults = .standard) {
    self.manager = manager
    self.consentDefaults = consentDefaults
    self.maxDurationSeconds = manager.configuration.maxDurationSeconds
  }

  public func reportVideoProcessingFailure() {
    lastErrorMessage = "视频处理失败,请重试"
  }

  deinit {
    observeTask?.cancel()
  }

  // MARK: - Consent (local-only in V0.1; see spec 027 Implementation Notes)

  public var hasConsented: Bool {
    consentDefaults.bool(forKey: Self.consentDefaultsKey)
  }

  public func recordConsent() {
    consentDefaults.set(true, forKey: Self.consentDefaultsKey)
  }

  // MARK: - Lifecycle

  /// Reconnects interrupted background work, loads existing attachments, and
  /// starts observing manager events. Idempotent.
  public func start(studentID: UUID) async {
    guard observeTask == nil else { return }
    observeTask = Task { [weak self] in
      guard let stream = await self?.manager.events() else { return }
      for await event in stream {
        self?.apply(event)
      }
    }

    await manager.recoverInterruptedUploads(studentID: studentID)
    for attachment in await manager.attachments(studentID: studentID) {
      rowStates[attachment.setLogID] = RowState(
        attachment: attachment,
        progress: attachment.status == .uploaded ? 1 : 0
      )
    }
  }

  // MARK: - Actions

  public func attach(
    sourceURL: URL,
    setLogID: UUID,
    studentID: UUID,
    trainingDate: Date? = nil
  ) async {
    lastErrorMessage = nil
    do {
      _ = try await manager.enqueue(
        sourceURL: sourceURL,
        setLogID: setLogID,
        studentID: studentID,
        trainingDate: trainingDate
      )
    } catch let error as VideoUploadError {
      lastErrorMessage = Self.message(for: error)
    } catch {
      lastErrorMessage = "视频处理失败,请重试"
    }
  }

  public func retry(setLogID: UUID) async {
    lastErrorMessage = nil
    retryErrorMessage = nil
    if let state = rowStates[setLogID] {
      await manager.retry(attachmentID: state.attachment.id)
    } else {
      await manager.retry(setLogID: setLogID)
    }
  }

  public func remove(setLogID: UUID) async {
    guard let state = rowStates[setLogID] else { return }
    await manager.remove(attachmentID: state.attachment.id)
  }

  public func clearRetryError() {
    retryErrorMessage = nil
  }

  func playbackSource(attachmentID: UUID) async throws -> VideoAttachmentPlaybackSource? {
    return try await manager.playbackSource(attachmentID: attachmentID)
  }

  func freshRemotePlaybackURL(attachmentID: UUID) async throws -> URL {
    try await manager.freshRemotePlaybackURL(attachmentID: attachmentID)
  }

  // MARK: - Internals

  private func apply(_ event: VideoUploadEvent) {
    switch event {
    case .updated(let attachment, let progress):
      var state =
        rowStates[attachment.setLogID]
        ?? RowState(attachment: attachment, progress: 0)
      state.attachment = attachment
      if let progress {
        state.progress = progress
      }
      rowStates[attachment.setLogID] = state
    case .removed(let setLogID, let attachmentID):
      if rowStates[setLogID]?.attachment.id == attachmentID {
        rowStates[setLogID] = nil
      }
    case .retryUnavailable(let setLogID, let attachmentID, let reason):
      guard rowStates[setLogID]?.attachment.id == attachmentID else { return }
      let message = Self.message(for: reason)
      lastErrorMessage = message
      retryErrorMessage = message
    }
  }

  private static func message(for reason: VideoRetryUnavailableReason) -> String {
    switch reason {
    case .sourceMissing:
      "本地视频已不存在,请删除后重新选择"
    }
  }

  private static func message(for error: VideoUploadError) -> String {
    switch error {
    case .durationExceedsLimit(_, let maxSeconds):
      "视频超过 \(Int(maxSeconds)) 秒上限,请截短后再上传"
    case .exportFailed:
      "视频转码失败,请重试"
    default:
      "视频处理失败,请重试"
    }
  }
}
