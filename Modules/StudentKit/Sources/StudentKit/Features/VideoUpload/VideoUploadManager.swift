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
  let localCleanupStore: any LocalVideoCleanupStoring
  let removeLocalFile: @Sendable (URL) throws -> Void
  private let networkMonitor: UploadNetworkMonitor?

  var activeUploads: [UUID: Task<Void, Never>] = [:]
  var activeUploadOwnerships: [UUID: Int] = [:]
  var removingRecordIDs: Set<UUID> = []
  var manualHarvestingRecordIDs: Set<UUID> = []
  var activeUploadOwnershipCounter = 0
  var scheduledRetries: [UUID: Task<Void, Never>] = [:]
  var scheduledRetryGenerations: [UUID: Int] = [:]
  var restoredBackgroundRecords: [String: [UUID: RestoredBackgroundRecord]] = [:]
  var backgroundEventDrainTasks: [String: Task<Void, Never>] = [:]
  var backgroundEventDrainTokens: [String: UUID] = [:]
  var drainingBackgroundSessionIdentifiers: Set<String> = []
  var drainingBackgroundRecordIDs: Set<UUID> = []
  var pendingBackgroundFinishTokens: [String: Set<BackgroundUploadEventToken>] = [:]
  var recoveringStudentIDs: Set<UUID> = []
  var retainingSourceRecordIDs: Set<UUID> = []
  /// Monotonic attempt identity per attachment. Chunk teardown advances the
  /// value, permanently invalidating every writer that captured an older one.
  /// Successful deletion advances once more and retains that value as an ABA
  /// tombstone for any suspended repository snapshot.
  var uploadGenerations: [UUID: Int] = [:]
  var nextUploadGeneration = 0
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
    localCleanupStore: (any LocalVideoCleanupStoring)? = nil,
    removeLocalFile: @escaping @Sendable (URL) throws -> Void = {
      try FileManager.default.removeItem(at: $0)
    },
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
    self.localCleanupStore =
      localCleanupStore
      ?? LocalVideoCleanupStore(
        fileURL: self.filesDirectory.appending(path: "pending-local-cleanup.json")
      )
    self.removeLocalFile = removeLocalFile
    self.networkMonitor = enableNetworkMonitoring ? UploadNetworkMonitor() : nil
  }

  // MARK: - Public API

  /// Validates duration, persists a `pending` record, and starts the
  /// export-and-upload task. Replaces any earlier video on the same set log
  /// (V0.1: one video per set).
  ///
  /// Ownership of `sourceURL` transfers to the manager when this method is
  /// called. The manager retains a private source copy until upload succeeds or
  /// the attachment is removed, so export failures can be retried.
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
    var retainedSourceURL: URL?
    var uploadTaskOwnsSource = false
    defer {
      if !uploadTaskOwnsSource {
        try? FileManager.default.removeItem(at: retainedSourceURL ?? sourceURL)
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
    retainingSourceRecordIDs.insert(id)
    defer { retainingSourceRecordIDs.remove(id) }
    try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    let managedSourceURL = sourceFileURL(
      recordID: id,
      pathExtension: sourceURL.pathExtension
    )
    try FileManager.default.moveItem(at: sourceURL, to: managedSourceURL)
    retainedSourceURL = managedSourceURL
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
    startUploadTask(recordID: id, sourceURL: managedSourceURL)
    uploadTaskOwnsSource = true
    return record
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

  func nextActiveUploadOwnership() -> Int {
    activeUploadOwnershipCounter += 1
    return activeUploadOwnershipCounter
  }

  @discardableResult
  func startUploadTask(
    recordID: UUID,
    sourceURL: URL?,
    previousGeneration: Int? = nil
  ) -> Task<Void, Never> {
    if let previousGeneration {
      nextUploadGeneration = max(nextUploadGeneration, previousGeneration)
    }
    let generation = advanceUploadGeneration(recordID: recordID)
    let ownership = nextActiveUploadOwnership()
    // Task {} inherits actor isolation, so the bookkeeping call is direct.
    let task = Task {
      await self.run(recordID: recordID, sourceURL: sourceURL, generation: generation)
      self.clearActiveUpload(recordID: recordID, ownership: ownership)
    }
    activeUploads[recordID] = task
    activeUploadOwnerships[recordID] = ownership
    return task
  }

  @discardableResult
  func startFailureTask(
    recordID: UUID,
    failure: VideoPartUploadFailure,
    generation: Int? = nil
  ) -> Task<Void, Never> {
    if let active = activeUploads[recordID] { return active }
    let failureGeneration =
      generation
      ?? uploadGenerations[recordID]
      ?? advanceUploadGeneration(recordID: recordID)
    let ownership = nextActiveUploadOwnership()
    let task = Task {
      await self.handleUploadFailure(
        recordID: recordID,
        error: failure,
        generation: failureGeneration
      )
      self.clearActiveUpload(recordID: recordID, ownership: ownership)
    }
    activeUploads[recordID] = task
    activeUploadOwnerships[recordID] = ownership
    return task
  }

  private func clearActiveUpload(recordID: UUID, ownership: Int) {
    guard activeUploadOwnerships[recordID] == ownership else { return }
    activeUploads[recordID] = nil
    activeUploadOwnerships[recordID] = nil
  }
}
