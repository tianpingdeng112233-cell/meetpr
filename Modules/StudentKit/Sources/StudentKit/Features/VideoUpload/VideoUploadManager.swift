import CoreModels
import Foundation
import Networking
import RepositoryContracts

/// Drives the set-video pipeline: H.264 export → file-backed multipart chunks
/// → `/uploads/initiate` → background PUTs → `/uploads/:id/complete`.
public actor VideoUploadManager {
  // Internal (not private): the upload pipeline lives in
  // VideoUploadManager+Pipeline.swift and needs these.
  let service: any VideoUploadService
  let exporter: any VideoExporting
  let repository: any VideoAttachmentRepository
  nonisolated let configuration: VideoUploadConfiguration
  let filesDirectory: URL
  let now: @Sendable () -> Date
  let retryScheduler: UploadRetryScheduler
  let failureNotifier: any UploadFailureNotifying
  let cleanupStore: any RemoteAttachmentCleanupStoring
  private let networkMonitor: UploadNetworkMonitor?

  var activeUploads: [UUID: Task<Void, Never>] = [:]
  var scheduledRetries: [UUID: Task<Void, Never>] = [:]
  var restoredBackgroundRecords: [String: [UUID: RestoredBackgroundRecord]] = [:]
  var recoveringStudentIDs: Set<UUID> = []
  private var observers: [UUID: AsyncStream<VideoUploadEvent>.Continuation] = [:]
  private var backgroundEventTask: Task<Void, Never>?
  private var networkEventTask: Task<Void, Never>?
  private var requestedNotificationAuthorization = false
  var lastNetworkAvailable: Bool?

  public init(
    service: any VideoUploadService,
    exporter: any VideoExporting,
    repository: any VideoAttachmentRepository,
    configuration: VideoUploadConfiguration = .default,
    filesDirectory: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() },
    retryScheduler: UploadRetryScheduler = UploadRetryScheduler(),
    failureNotifier: (any UploadFailureNotifying)? = nil,
    cleanupStore: (any RemoteAttachmentCleanupStoring)? = nil,
    enableNetworkMonitoring: Bool = false
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
    self.retryScheduler = retryScheduler
    self.failureNotifier = failureNotifier ?? NoopUploadFailureNotifier()
    self.cleanupStore =
      cleanupStore
      ?? RemoteAttachmentCleanupStore(
        fileURL: self.filesDirectory.appending(path: "pending-remote-cleanup.json")
      )
    self.networkMonitor = enableNetworkMonitoring ? UploadNetworkMonitor() : nil
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
    trainingDate: Date? = nil,
    recordedAt: Date? = nil
  ) async throws -> VideoAttachment {
    activateBackgroundHandling()
    if !requestedNotificationAuthorization {
      requestedNotificationAuthorization = true
      await failureNotifier.requestProvisionalAuthorization()
    }
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
      recordedAt: recordedAt ?? now(),
      trainingDate: trainingDate
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

    scheduledRetries[attachmentID]?.cancel()
    scheduledRetries[attachmentID] = nil
    await service.cancelParts(recordID: attachmentID)
    guard await abandonRemoteSession(record: &record) else { return }
    record.uploadRetryCount = 0
    record.firstUploadFailureAt = nil
    record.status = .pending
    try? await repository.save(record)
    broadcast(.updated(record, progress: 0))
    startUploadTask(recordID: attachmentID, sourceURL: nil)
  }

  public func retry(setLogID: UUID) async {
    guard
      let attachment = try? await repository.fetch(setLogID: setLogID)
        .last(where: { $0.status == .failed })
    else { return }
    await retry(attachmentID: attachment.id)
  }

  /// Cancels any in-flight upload, abandons an unfinished remote upload, and
  /// deletes all local record, video, and chunk files. A ready attachment is
  /// only unlinked locally because the upload abort endpoint rejects it.
  public func remove(attachmentID: UUID) async {
    if let task = activeUploads[attachmentID] {
      task.cancel()
      activeUploads[attachmentID] = nil
    }
    scheduledRetries[attachmentID]?.cancel()
    scheduledRetries[attachmentID] = nil
    await service.cancelParts(recordID: attachmentID)
    guard var record = try? await repository.fetch(id: attachmentID) else { return }

    if record.status != .uploaded {
      guard await abandonRemoteSession(record: &record) else { return }
    }
    try? FileManager.default.removeItem(at: fileURL(for: record))
    removeChunkFiles(recordID: attachmentID)
    try? await repository.delete(id: attachmentID)
    broadcast(.removed(setLogID: record.setLogID, attachmentID: attachmentID))
  }

  /// App-launch recovery reconnects to restored background tasks, resumes any
  /// locally persisted retry window, and finishes complete when all ETags are
  /// already present.
  public func recoverInterruptedUploads(studentID: UUID) async {
    activateBackgroundHandling()
    recoveringStudentIDs.insert(studentID)
    await flushPendingRemoteCleanups()
    guard await !service.isBackgroundWakeActive() else { return }
    _ = await recoverDormantUploads(studentID: studentID)
  }

  func recoverDormantUploads(studentID: UUID) async -> [Task<Void, Never>] {
    var startedTasks: [Task<Void, Never>] = []
    let records = (try? await repository.fetchAll(studentID: studentID)) ?? []
    for storedRecord in records where storedRecord.status == .failed {
      guard storedRecord.remoteAttachmentID != nil else { continue }
      var record = storedRecord
      if await abandonRemoteSession(record: &record) {
        try? await repository.save(record)
      }
    }
    for record in records where record.status != .uploaded && record.status != .failed {
      guard activeUploads[record.id] == nil, scheduledRetries[record.id] == nil else { continue }
      if let firstFailureAt = record.firstUploadFailureAt {
        scheduleRetry(
          record: record,
          firstFailureAt: firstFailureAt,
          networkState: .available
        )
        continue
      }
      let pendingParts = await service.pendingPartNumbers(recordID: record.id)
      if !pendingParts.isEmpty { continue }
      guard FileManager.default.fileExists(atPath: fileURL(for: record).path) else {
        await transitionToTerminalFailure(record)
        continue
      }
      startedTasks.append(startUploadTask(recordID: record.id, sourceURL: nil))
    }
    return startedTasks
  }

  func activateBackgroundHandling() {
    if backgroundEventTask == nil {
      let events = service.backgroundEvents
      backgroundEventTask = Task { [weak self] in
        for await event in events {
          await self?.receiveBackgroundEvent(event)
        }
      }
    }
    if networkEventTask == nil, let networkMonitor {
      let updates = networkMonitor.updates
      networkEventTask = Task { [weak self] in
        for await available in updates {
          await self?.networkAvailabilityChanged(available)
        }
      }
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

  private func removeObserver(_ observerID: UUID) {
    observers[observerID]?.finish()
    observers[observerID] = nil
  }

  @discardableResult
  func startUploadTask(recordID: UUID, sourceURL: URL?) -> Task<Void, Never> {
    // Task {} inherits actor isolation, so the bookkeeping call is direct.
    let task = Task {
      await self.run(recordID: recordID, sourceURL: sourceURL)
      self.clearActiveUpload(recordID: recordID)
    }
    activeUploads[recordID] = task
    return task
  }

  @discardableResult
  func startFailureTask(
    recordID: UUID,
    failure: VideoPartUploadFailure
  ) -> Task<Void, Never> {
    if let active = activeUploads[recordID] { return active }
    let task = Task {
      await self.handleUploadFailure(recordID: recordID, error: failure)
      self.clearActiveUpload(recordID: recordID)
    }
    activeUploads[recordID] = task
    return task
  }

  private func clearActiveUpload(recordID: UUID) {
    activeUploads[recordID] = nil
  }
}
