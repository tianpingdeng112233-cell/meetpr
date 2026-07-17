import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// Drives the spec 027 student video pipeline: H.264 export → 5 MB chunking →
/// `/uploads/initiate` → concurrent presigned part PUTs (2 retries each) →
/// `/uploads/:id/complete`; abort on cancel/failure.
///
/// V0.1 deliberately has no BackgroundURLSession resume: uploads run while the
/// app is alive, and `recoverInterruptedUploads` marks anything interrupted by
/// an app kill as `failed` (retryable from scratch) on next launch.
public actor VideoUploadManager {
  // Internal (not private): the upload pipeline lives in
  // VideoUploadManager+Pipeline.swift and needs these.
  let service: any VideoUploadService
  let exporter: any VideoExporting
  let repository: any VideoAttachmentRepository
  let configuration: VideoUploadConfiguration
  let filesDirectory: URL
  let now: @Sendable () -> Date

  private var activeUploads: [UUID: Task<Void, Never>] = [:]
  private var observers: [UUID: AsyncStream<VideoUploadEvent>.Continuation] = [:]

  public init(
    service: any VideoUploadService,
    exporter: any VideoExporting,
    repository: any VideoAttachmentRepository,
    configuration: VideoUploadConfiguration = .default,
    filesDirectory: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.service = service
    self.exporter = exporter
    self.repository = repository
    self.configuration = configuration
    self.filesDirectory =
      filesDirectory
      ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("video_uploads", isDirectory: true)
      .appendingPathComponent("files", isDirectory: true)
    self.now = now
  }

  // MARK: - Public API

  /// Validates duration, persists a `pending` record, and starts the
  /// export-and-upload task. Replaces any earlier video on the same set log
  /// (V0.1: one video per set).
  ///
  /// Ownership of `sourceURL` transfers to the manager when this method is
  /// called. The manager removes the file on every outcome; the caller must
  /// not use it after `enqueue` returns, whether the call succeeds or throws.
  public func enqueue(
    sourceURL: URL,
    setLogID: UUID,
    studentID: UUID,
    recordedAt: Date? = nil
  ) async throws -> VideoAttachment {
    var uploadTaskOwnsSource = false
    defer {
      if !uploadTaskOwnsSource {
        try? FileManager.default.removeItem(at: sourceURL)
      }
    }

    let duration = try await exporter.durationSeconds(of: sourceURL)
    guard duration <= configuration.maxDurationSeconds else {
      throw VideoUploadError.durationExceedsLimit(
        seconds: duration,
        maxSeconds: configuration.maxDurationSeconds
      )
    }

    for existing in (try? await repository.fetch(setLogID: setLogID)) ?? [] {
      await remove(attachmentID: existing.id)
    }

    let id = UUID()
    let record = VideoAttachment(
      id: id,
      setLogID: setLogID,
      studentID: studentID,
      status: .pending,
      contentType: "video/mp4",
      durationSeconds: duration,
      sizeBytes: 0,
      localFileName: "\(id.uuidString).mp4",
      recordedAt: recordedAt ?? now()
    )
    try await repository.save(record)
    broadcast(.updated(record, progress: 0))
    startUploadTask(recordID: id, sourceURL: sourceURL)
    uploadTaskOwnsSource = true
    return record
  }

  /// Re-runs a `failed` upload from scratch: the stale backend row (if any)
  /// stays `uploading` server-side per backend spec 004; a fresh initiate
  /// produces a new attachment row.
  public func retry(attachmentID: UUID) async {
    guard activeUploads[attachmentID] == nil,
      var record = try? await repository.fetch(id: attachmentID),
      record.status == .failed
    else { return }

    guard FileManager.default.fileExists(atPath: fileURL(for: record).path) else {
      broadcast(.updated(record, progress: nil))
      return
    }

    record.remoteAttachmentID = nil
    record.status = .pending
    try? await repository.save(record)
    broadcast(.updated(record, progress: 0))
    startUploadTask(recordID: attachmentID, sourceURL: nil)
  }

  /// Cancels any in-flight upload, best-effort aborts the backend upload, and
  /// deletes the local record + file. An `uploaded` attachment only loses its
  /// local record — V0.1 has no backend DELETE endpoint.
  public func remove(attachmentID: UUID) async {
    if let task = activeUploads[attachmentID] {
      task.cancel()
      activeUploads[attachmentID] = nil
    }
    guard let record = try? await repository.fetch(id: attachmentID) else { return }

    if let remoteID = record.remoteAttachmentID, record.status != .uploaded {
      try? await service.abort(attachmentID: remoteID)
    }
    try? FileManager.default.removeItem(at: fileURL(for: record))
    try? await repository.delete(id: attachmentID)
    broadcast(.removed(setLogID: record.setLogID, attachmentID: attachmentID))
  }

  /// App-launch recovery: anything still `pending`/`uploading` was interrupted
  /// by a kill and becomes `failed` (retryable), per spec 027 V0.1 scope.
  public func recoverInterruptedUploads(studentID: UUID) async {
    let records = (try? await repository.fetchAll(studentID: studentID)) ?? []
    for var record in records
    where record.status != .uploaded && record.status != .failed
      && activeUploads[record.id] == nil
    {
      record.status = .failed
      record.remoteAttachmentID = nil
      try? await repository.save(record)
      broadcast(.updated(record, progress: nil))
    }
  }

  public func attachments(studentID: UUID) async -> [VideoAttachment] {
    ((try? await repository.fetchAll(studentID: studentID)) ?? [])
      .sorted { $0.recordedAt > $1.recordedAt }
  }

  public func events() -> AsyncStream<VideoUploadEvent> {
    let observerID = UUID()
    let (stream, continuation) = AsyncStream.makeStream(
      of: VideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(64)
    )
    observers[observerID] = continuation
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeObserver(observerID) }
    }
    return stream
  }

  // MARK: - Internals shared with the pipeline extension

  func broadcast(_ event: VideoUploadEvent) {
    for continuation in observers.values {
      continuation.yield(event)
    }
  }

  func fileURL(for record: VideoAttachment) -> URL {
    filesDirectory.appendingPathComponent(record.localFileName ?? "\(record.id.uuidString).mp4")
  }

  private func removeObserver(_ observerID: UUID) {
    observers[observerID]?.finish()
    observers[observerID] = nil
  }

  private func startUploadTask(recordID: UUID, sourceURL: URL?) {
    // Task {} inherits actor isolation, so the bookkeeping call is direct.
    activeUploads[recordID] = Task {
      await self.run(recordID: recordID, sourceURL: sourceURL)
      self.clearActiveUpload(recordID: recordID)
    }
  }

  private func clearActiveUpload(recordID: UUID) {
    activeUploads[recordID] = nil
  }
}
