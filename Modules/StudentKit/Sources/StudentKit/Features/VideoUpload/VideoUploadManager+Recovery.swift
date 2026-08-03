import Analytics
import CoreModels
import Foundation
import Networking

struct RestoredBackgroundRecord: Sendable {
  var tokens: Set<BackgroundUploadEventToken> = []
  var failure: VideoPartUploadFailure?
}

extension VideoUploadManager {
  func receiveBackgroundEvent(_ event: BackgroundVideoUploadEvent) async {
    switch event {
    case .part(let partEvent):
      await receiveBackgroundPartEvent(partEvent)
    case .sessionEventsFinished(let identifier, let completionToken):
      await finishBackgroundSessionEvents(
        identifier: identifier,
        completionToken: completionToken
      )
    }
  }

  private func receiveBackgroundPartEvent(_ event: BackgroundVideoPartEvent) async {
    let recordID = event.identifier.recordID
    if event.hasPipelineContinuation,
      !BackgroundUploadCompletionRegistry.shared.hasPendingHandler(
        identifier: event.completionToken.sessionIdentifier
      )
    {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
      return
    }

    guard let record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed
    else {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
      return
    }

    var pending = restoredBackgroundRecords[event.completionToken.sessionIdentifier, default: [:]]
    var restoredRecord = pending[recordID, default: RestoredBackgroundRecord()]
    restoredRecord.tokens.insert(event.completionToken)
    switch event.result {
    case .success(let etag):
      do {
        try await persist(
          part: VideoUploadedPart(partNumber: event.identifier.partNumber, etag: etag),
          recordID: recordID
        )
      } catch {
        restoredRecord.failure = .unknown
      }
    case .failure(let failure):
      if failure != .cancelled || restoredRecord.failure == nil {
        restoredRecord.failure = failure
      }
    }
    pending[recordID] = restoredRecord
    restoredBackgroundRecords[event.completionToken.sessionIdentifier] = pending
  }

  private func finishBackgroundSessionEvents(
    identifier: String,
    completionToken: BackgroundUploadEventToken
  ) async {
    let records = restoredBackgroundRecords.removeValue(forKey: identifier) ?? [:]
    for (recordID, restoredRecord) in records {
      if let failure = restoredRecord.failure {
        await handleUploadFailure(recordID: recordID, error: failure)
      } else {
        await continueDuringBackgroundWake(recordID: recordID)
      }

      for token in restoredRecord.tokens {
        BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(token)
      }
    }

    let restoredRecordIDs = Set(records.keys)
    for studentID in recoveringStudentIDs {
      let dormantRecords = (try? await repository.fetchAll(studentID: studentID)) ?? []
      for record in dormantRecords
      where record.status != .uploaded
        && record.status != .failed
        && !restoredRecordIDs.contains(record.id)
      {
        await continueDuringBackgroundWake(recordID: record.id)
      }
    }
    BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(completionToken)
  }

  /// Drains only bounded work while iOS is waiting for its background-session
  /// completion handler. Completed transfers may call the quick backend
  /// `/complete`; incomplete transfers enqueue the next file-backed batch and
  /// return without awaiting network I/O.
  private func continueDuringBackgroundWake(recordID: UUID) async {
    guard var record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed
    else { return }

    do {
      let fileLocation = fileURL(for: record)
      guard FileManager.default.fileExists(atPath: fileLocation.path) else {
        throw VideoUploadError.localFileMissing
      }
      let chunker = VideoFileChunker(partSizeBytes: configuration.partSizeBytes)
      let partCount = try chunker.partCount(totalBytes: record.sizeBytes)
      let resolved = try await resolveBackgroundWakePlan(record: &record, partCount: partCount)
      try await executeBackgroundWakePlan(
        resolved,
        record: record,
        chunker: chunker,
        fileLocation: fileLocation
      )
    } catch {
      await handleUploadFailure(recordID: recordID, error: error)
    }
  }

  private func resolveBackgroundWakePlan(
    record: inout VideoAttachment,
    partCount: Int
  ) async throws -> BackgroundUploadWakePlanner.Decision {
    var pendingPartNumbers = await service.pendingPartNumbers(recordID: record.id)
    var decision = backgroundWakeDecision(record: record, pendingParts: pendingPartNumbers)
    guard decision == .prepareRemoteSession else { return decision }
    guard record.remoteAttachmentID == nil else {
      throw VideoUploadError.partURLCountMismatch(
        expected: partCount,
        received: record.uploadPartTargets.count
      )
    }

    record.status = .uploading
    try await repository.save(record)
    record = try await initiate(record, partCount: partCount)
    pendingPartNumbers = await service.pendingPartNumbers(recordID: record.id)
    decision = backgroundWakeDecision(record: record, pendingParts: pendingPartNumbers)
    return decision
  }

  private func backgroundWakeDecision(
    record: VideoAttachment,
    pendingParts: Set<Int>
  ) -> BackgroundUploadWakePlanner.Decision {
    BackgroundUploadWakePlanner().decision(
      partCount: record.uploadPartCount,
      targetPartNumbers: Set(record.uploadPartTargets.map(\.partNumber)),
      completedPartNumbers: Set(record.uploadedParts.map(\.partNumber)),
      pendingPartNumbers: pendingParts,
      maxConcurrentParts: configuration.maxConcurrentParts
    )
  }

  private func executeBackgroundWakePlan(
    _ decision: BackgroundUploadWakePlanner.Decision,
    record: VideoAttachment,
    chunker: VideoFileChunker,
    fileLocation: URL
  ) async throws {
    switch decision {
    case .complete:
      try await completeDuringBackgroundWake(record)
    case .scheduleParts(let partNumbers):
      try await scheduleBackgroundParts(
        partNumbers,
        record: record,
        chunker: chunker,
        fileLocation: fileLocation
      )
    case .waitForScheduledParts:
      break
    case .prepareRemoteSession:
      throw VideoUploadError.fileUnreadable
    }
  }

  private func completeDuringBackgroundWake(_ record: VideoAttachment) async throws {
    guard let remoteID = record.remoteAttachmentID else {
      throw VideoUploadError.fileUnreadable
    }
    let etags = record.uploadedParts
      .sorted { $0.partNumber < $1.partNumber }
      .map { UploadPartETagDTO(partNumber: $0.partNumber, etag: $0.etag) }
    try await complete(record, remoteID: remoteID, etags: etags)
  }

  private func scheduleBackgroundParts(
    _ partNumbers: [Int],
    record: VideoAttachment,
    chunker: VideoFileChunker,
    fileLocation: URL
  ) async throws {
    let targets = Dictionary(
      uniqueKeysWithValues: record.uploadPartTargets.map { ($0.partNumber, $0.url) }
    )
    let chunkDirectory = chunkDirectory(recordID: record.id)
    for partNumber in partNumbers {
      guard let target = targets[partNumber] else {
        throw VideoUploadError.invalidPartURL(partNumber: partNumber)
      }
      let partFile = try chunker.writePart(
        partNumber: partNumber,
        from: fileLocation,
        to: chunkDirectory
      )
      try await service.schedulePart(
        to: target,
        from: partFile,
        identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: partNumber)
      )
    }
  }

  func networkAvailabilityChanged(_ available: Bool) async {
    let wasAvailable = lastNetworkAvailable
    lastNetworkAvailable = available
    guard available, wasAvailable == false else { return }

    await flushPendingRemoteCleanups()
    let retryIDs = Array(scheduledRetries.keys)
    for recordID in retryIDs {
      scheduledRetries[recordID]?.cancel()
      scheduledRetries[recordID] = nil
      guard let record = try? await repository.fetch(id: recordID),
        let firstFailureAt = record.firstUploadFailureAt
      else { continue }
      scheduleRetry(record: record, firstFailureAt: firstFailureAt, networkState: .restored)
    }
  }

  func handleUploadFailure(recordID: UUID, error: any Error) async {
    guard !Task.isCancelled,
      var record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed
    else { return }

    await service.cancelParts(recordID: recordID)
    if Self.requiresFreshRemoteSession(for: error) {
      _ = await abandonRemoteSession(record: &record)
    }
    let firstFailureAt = record.firstUploadFailureAt ?? now()
    record.firstUploadFailureAt = firstFailureAt
    record.uploadRetryCount += 1
    record.status = .pending
    try? await repository.save(record)
    broadcast(.updated(record, progress: nil))

    let failureKind = Self.failureKind(for: error)
    if failureKind == .deterministic {
      await transitionToTerminalFailure(
        record,
        abandonsRemoteSession: (error as? VideoUploadError) != .completeConflict
      )
      return
    }
    scheduleRetry(record: record, firstFailureAt: firstFailureAt, networkState: .available)
  }

  func scheduleRetry(
    record: VideoAttachment,
    firstFailureAt: Date,
    networkState: UploadRetryScheduler.NetworkState
  ) {
    let decision = retryScheduler.decision(
      failure: .transient,
      retryCount: record.uploadRetryCount,
      firstFailureAt: firstFailureAt,
      now: now(),
      networkState: networkState
    )
    switch decision {
    case .retryNow:
      startRecoveredUpload(record)
    case .retryAfter(let seconds):
      scheduledRetries[record.id]?.cancel()
      scheduledRetries[record.id] = Task { [weak self] in
        do {
          try await Task.sleep(for: .seconds(seconds))
          await self?.retryTimerFired(recordID: record.id)
        } catch {}
      }
    case .terminalFailure:
      Task { [weak self] in
        await self?.transitionToTerminalFailure(record)
      }
    }
  }

  func retryTimerFired(recordID: UUID) async {
    scheduledRetries[recordID] = nil
    guard let record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed,
      let firstFailureAt = record.firstUploadFailureAt
    else { return }
    if now().timeIntervalSince(firstFailureAt) >= retryScheduler.timeBoxSeconds {
      await transitionToTerminalFailure(record)
    } else {
      startRecoveredUpload(record)
    }
  }

  func transitionToTerminalFailure(
    _ staleRecord: VideoAttachment,
    abandonsRemoteSession: Bool = true
  ) async {
    guard var record = try? await repository.fetch(id: staleRecord.id),
      record.status != .uploaded
    else { return }
    scheduledRetries[record.id]?.cancel()
    scheduledRetries[record.id] = nil
    await service.cancelParts(recordID: record.id)
    if abandonsRemoteSession {
      _ = await abandonRemoteSession(record: &record)
    } else {
      resetRemoteSession(on: &record)
    }
    record.status = .failed
    try? await repository.save(record)
    removeChunkFiles(recordID: record.id)
    broadcast(.updated(record, progress: nil))
    Analytics.shared.mediaUpload(
      .failed,
      context: .setLog,
      bytes: Int(clamping: record.sizeBytes)
    )
    let records = (try? await repository.fetchAll(studentID: record.studentID)) ?? []
    await failureNotifier.notifyTerminalFailures(
      count: records.filter { $0.status == .failed }.count,
      destination: UploadFailureDestination(
        setLogID: record.setLogID,
        trainingDate: record.trainingDate
      )
    )
  }

  private func startRecoveredUpload(_ record: VideoAttachment) {
    guard activeUploads[record.id] == nil else { return }
    startUploadTask(recordID: record.id, sourceURL: nil)
  }

  static func requiresFreshRemoteSession(for error: any Error) -> Bool {
    (error as? VideoPartUploadFailure) == .httpStatus(403)
  }

  static func failureKind(for error: any Error) -> UploadRetryScheduler.FailureKind {
    if let partFailure = error as? VideoPartUploadFailure {
      switch partFailure {
      case .httpStatus(let statusCode):
        return statusCode == 403 || statusCode >= 500 ? .transient : .deterministic
      case .network, .invalidResponse, .missingETag, .unknown:
        return .transient
      case .cancelled:
        return .transient
      }
    }
    if let apiError = error as? APIError {
      switch apiError {
      case .httpStatus(let statusCode, _):
        return (400..<500).contains(statusCode) ? .deterministic : .transient
      case .authInvalid:
        return .deterministic
      case .invalidResponse:
        return .transient
      }
    }
    if let uploadError = error as? VideoUploadError {
      switch uploadError {
      case .durationExceedsLimit, .exportFailed, .emptyFile, .fileUnreadable,
        .localFileMissing, .invalidPartURL, .partURLCountMismatch, .completeConflict:
        return .deterministic
      }
    }
    return .transient
  }
}
