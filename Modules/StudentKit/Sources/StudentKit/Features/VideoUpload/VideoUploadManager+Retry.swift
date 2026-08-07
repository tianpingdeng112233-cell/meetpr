import Analytics
import CoreModels
import Foundation
import Networking

extension VideoUploadManager {
  /// Re-runs a `failed` upload from scratch: the stale backend row (if any)
  /// stays `uploading` server-side per backend spec 004; a fresh initiate
  /// produces a new attachment row.
  public func retry(attachmentID: UUID) async {
    guard !removingRecordIDs.contains(attachmentID),
      activeUploads[attachmentID] == nil,
      var record = try? await repository.fetch(id: attachmentID),
      record.status == .failed
    else { return }
    guard let retryGeneration = try? requireLiveSnapshotGeneration(from: record) else { return }

    guard FileManager.default.fileExists(atPath: fileURL(for: record).path) else {
      broadcast(.updated(record, progress: nil))
      return
    }

    scheduledRetries[attachmentID]?.cancel()
    scheduledRetries[attachmentID] = nil
    scheduledRetryGenerations[attachmentID] = nil
    await service.cancelParts(recordID: attachmentID)
    guard isLiveRetryContext(recordID: attachmentID, generation: retryGeneration) else { return }
    guard await abandonRemoteSession(record: &record) else { return }
    guard isLiveRetryContext(recordID: attachmentID, generation: retryGeneration) else { return }
    record.uploadRetryCount = 0
    record.firstUploadFailureAt = nil
    record.status = .pending
    guard isLiveRetryContext(recordID: attachmentID, generation: retryGeneration) else { return }
    try? await repository.save(record)
    guard isLiveRetryContext(recordID: attachmentID, generation: retryGeneration) else { return }
    broadcast(.updated(record, progress: 0))
    startUploadTask(
      recordID: attachmentID,
      sourceURL: nil,
      previousGeneration: retryGeneration
    )
  }

  public func retry(setLogID: UUID) async {
    guard
      let attachment = try? await repository.fetch(setLogID: setLogID)
        .last(where: { $0.status == .failed })
    else { return }
    await retry(attachmentID: attachment.id)
  }

  private func isLiveRetryContext(recordID: UUID, generation: Int) -> Bool {
    (try? requireLiveWakeContext(recordID: recordID, generation: generation)) != nil
  }

  func networkAvailabilityChanged(_ available: Bool) async {
    let wasAvailable = lastNetworkAvailable
    lastNetworkAvailable = available
    guard available, wasAvailable == false else { return }

    let retryContexts = scheduledRetryGenerations
    await flushPendingRemoteCleanups()
    for (recordID, generation) in retryContexts {
      guard scheduledRetryGenerations[recordID] == generation,
        isLiveRetryContext(recordID: recordID, generation: generation)
      else { continue }
      scheduledRetries[recordID]?.cancel()
      scheduledRetries[recordID] = nil
      scheduledRetryGenerations[recordID] = nil
      guard isLiveRetryContext(recordID: recordID, generation: generation) else { continue }
      guard let record = try? await repository.fetch(id: recordID),
        let firstFailureAt = record.firstUploadFailureAt
      else { continue }
      guard isLiveRetryContext(recordID: recordID, generation: generation) else { continue }
      scheduleRetry(
        record: record,
        firstFailureAt: firstFailureAt,
        networkState: .restored,
        generation: generation
      )
    }
  }

  func handleUploadFailure(recordID: UUID, error: any Error, generation: Int) async {
    guard !Task.isCancelled, isLiveRetryContext(recordID: recordID, generation: generation),
      var record = try? await repository.fetch(id: recordID)
    else { return }
    guard !Task.isCancelled,
      isLiveRetryContext(recordID: recordID, generation: generation),
      record.status != .uploaded,
      record.status != .failed
    else { return }

    await service.cancelParts(recordID: recordID)
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    if Self.requiresFreshRemoteSession(for: error) {
      _ = await abandonRemoteSession(record: &record)
      guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    }
    let firstFailureAt = record.firstUploadFailureAt ?? now()
    record.firstUploadFailureAt = firstFailureAt
    record.uploadRetryCount += 1
    record.status = .pending
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    try? await repository.save(record)
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    broadcast(.updated(record, progress: nil))

    let failureKind = Self.failureKind(for: error)
    if failureKind == .deterministic {
      await transitionToTerminalFailure(
        record,
        abandonsRemoteSession: (error as? VideoUploadError) != .completeConflict,
        generation: generation
      )
      return
    }
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    scheduleRetry(
      record: record,
      firstFailureAt: firstFailureAt,
      networkState: .available,
      generation: generation
    )
  }

  @discardableResult
  func scheduleRetry(
    record: VideoAttachment,
    firstFailureAt: Date,
    networkState: UploadRetryScheduler.NetworkState,
    generation: Int
  ) -> Task<Void, Never>? {
    guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    let decision = retryScheduler.decision(
      failure: .transient,
      retryCount: record.uploadRetryCount,
      firstFailureAt: firstFailureAt,
      now: now(),
      networkState: networkState
    )
    switch decision {
    case .retryNow:
      startRecoveredUpload(record, generation: generation)
      return nil
    case .retryAfter(let seconds):
      scheduledRetries[record.id]?.cancel()
      scheduledRetryGenerations[record.id] = generation
      let task = Task { [weak self] in
        do {
          try await Task.sleep(for: .seconds(seconds))
          await self?.retryTimerFired(recordID: record.id, generation: generation)
        } catch {}
      }
      scheduledRetries[record.id] = task
      return task
    case .terminalFailure:
      return Task { [weak self] in
        await self?.transitionToTerminalFailure(record, generation: generation)
      }
    }
  }

  func retryTimerFired(recordID: UUID, generation: Int) async {
    guard scheduledRetryGenerations[recordID] == generation,
      isLiveRetryContext(recordID: recordID, generation: generation)
    else { return }
    scheduledRetries[recordID] = nil
    scheduledRetryGenerations[recordID] = nil
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    guard let record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed,
      let firstFailureAt = record.firstUploadFailureAt
    else { return }
    guard isLiveRetryContext(recordID: recordID, generation: generation) else { return }
    if now().timeIntervalSince(firstFailureAt) >= retryScheduler.timeBoxSeconds {
      await transitionToTerminalFailure(record, generation: generation)
    } else {
      startRecoveredUpload(record, generation: generation)
    }
  }

  func transitionToTerminalFailure(
    _ staleRecord: VideoAttachment,
    abandonsRemoteSession: Bool = true,
    generation: Int
  ) async {
    guard
      let record = await prepareTerminalFailureRecord(
        staleRecord,
        abandonsRemoteSession: abandonsRemoteSession,
        generation: generation
      )
    else { return }
    let cleanupGeneration = await removeChunkFiles(recordID: record.id)
    guard isLiveRetryContext(recordID: record.id, generation: cleanupGeneration) else { return }
    broadcast(.updated(record, progress: nil))
    Analytics.shared.mediaUpload(
      .failed,
      context: .setLog,
      bytes: Int(clamping: record.sizeBytes)
    )
    let records = (try? await repository.fetchAll(studentID: record.studentID)) ?? []
    guard isLiveRetryContext(recordID: record.id, generation: cleanupGeneration) else { return }
    await failureNotifier.notifyTerminalFailures(
      count: records.filter { $0.status == .failed }.count,
      destination: UploadFailureDestination(
        setLogID: record.setLogID,
        trainingDate: record.trainingDate
      )
    )
    guard isLiveRetryContext(recordID: record.id, generation: cleanupGeneration) else { return }
  }

  private func prepareTerminalFailureRecord(
    _ staleRecord: VideoAttachment,
    abandonsRemoteSession: Bool,
    generation: Int
  ) async -> VideoAttachment? {
    guard isLiveRetryContext(recordID: staleRecord.id, generation: generation) else {
      return nil
    }
    guard var record = try? await repository.fetch(id: staleRecord.id),
      record.status != .uploaded
    else { return nil }
    guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    scheduledRetries[record.id]?.cancel()
    scheduledRetries[record.id] = nil
    scheduledRetryGenerations[record.id] = nil
    await service.cancelParts(recordID: record.id)
    guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    if abandonsRemoteSession {
      _ = await abandonRemoteSession(record: &record)
      guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    } else {
      resetRemoteSession(on: &record)
    }
    record.status = .failed
    guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    try? await repository.save(record)
    guard isLiveRetryContext(recordID: record.id, generation: generation) else { return nil }
    return record
  }

  private func startRecoveredUpload(_ record: VideoAttachment, generation: Int) {
    guard activeUploads[record.id] == nil,
      isLiveRetryContext(recordID: record.id, generation: generation)
    else { return }
    startUploadTask(
      recordID: record.id,
      sourceURL: nil,
      previousGeneration: generation
    )
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
