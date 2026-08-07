import Analytics
import CoreModels
import Foundation
import Networking

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
    guard let record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed
    else {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
      return
    }
    guard matchesPersistedUploadGeneration(event.identifier.generation, record: record) else {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
      return
    }
    if event.hasPipelineContinuation,
      !BackgroundUploadCompletionRegistry.shared.hasPendingHandler(
        identifier: event.completionToken.sessionIdentifier
      )
    {
      BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(event.completionToken)
      return
    }

    var pending = restoredBackgroundRecords[event.completionToken.sessionIdentifier, default: [:]]
    var restoredRecord = pending[recordID, default: RestoredBackgroundRecord()]
    restoredRecord.tokens.insert(event.completionToken)
    restoredRecord.generation = event.identifier.generation
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
      if let failure = restoredRecord.failure,
        let generation = restoredRecord.generation
      {
        await handleUploadFailure(
          recordID: recordID,
          error: failure,
          generation: generation
        )
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
      // Records with a live pipeline task are not dormant: waking them here
      // would run a second writer under the same generation (duplicate part
      // writes/PUTs, spurious localFileMissing before the export lands).
      for record in dormantRecords
      where record.status != .uploaded
        && record.status != .failed
        && !restoredRecordIDs.contains(record.id)
        && activeUploads[record.id] == nil
        && scheduledRetries[record.id] == nil
        && !removingRecordIDs.contains(record.id)
      {
        await continueDuringBackgroundWake(record)
      }
    }
    BackgroundUploadCompletionRegistry.shared.acknowledgeEvent(completionToken)
  }

  /// Drains only bounded work while iOS is waiting for its background-session
  /// completion handler. Completed transfers may call the quick backend
  /// `/complete`; incomplete transfers enqueue the next file-backed batch and
  /// return without awaiting network I/O.
  func continueDuringBackgroundWake(recordID: UUID) async {
    guard !removingRecordIDs.contains(recordID),
      let record = try? await repository.fetch(id: recordID),
      record.status != .uploaded,
      record.status != .failed
    else { return }
    await continueDuringBackgroundWake(record)
  }

  private func continueDuringBackgroundWake(_ record: VideoAttachment) async {
    guard record.status != .uploaded,
      record.status != .failed,
      let initialGeneration = try? requireLiveSnapshotGeneration(from: record)
    else { return }
    await drainBackgroundWake(record, initialGeneration: initialGeneration)
  }

  private func drainBackgroundWake(
    _ storedRecord: VideoAttachment,
    initialGeneration: Int
  ) async {
    let recordID = storedRecord.id
    var record = storedRecord
    var wakeGeneration: Int?
    do {
      wakeGeneration = initialGeneration
      let prepared = try await prepareBackgroundWakeRecord(
        record,
        initialGeneration: initialGeneration
      )
      record = prepared.record
      let generation = prepared.generation
      wakeGeneration = generation
      let input = try backgroundWakeInput(for: record)
      try requireLiveWakeContext(recordID: recordID, generation: generation)
      let resolved = try await resolveBackgroundWakePlan(
        record: &record,
        partCount: input.partCount,
        generation: generation
      )
      try requireLiveWakeContext(recordID: recordID, generation: generation)
      let completedGeneration = try await executeBackgroundWakePlan(
        resolved,
        record: record,
        chunker: input.chunker,
        fileLocation: input.fileLocation,
        generation: generation
      )
      let liveGeneration = completedGeneration ?? generation
      wakeGeneration = liveGeneration
      try requireLiveWakeContext(
        recordID: recordID,
        generation: liveGeneration
      )
      if let completedGeneration {
        await reclaimUploadGeneration(completedGeneration, recordID: recordID)
      }
    } catch is CancellationError {
      return
    } catch {
      guard let wakeGeneration,
        wakeFailureContextIsLive(recordID: recordID, generation: wakeGeneration)
      else { return }
      await handleUploadFailure(
        recordID: recordID,
        error: error,
        generation: wakeGeneration
      )
    }
  }

  private func backgroundWakeInput(
    for record: VideoAttachment
  ) throws -> BackgroundUploadWakeInput {
    let fileLocation = fileURL(for: record)
    guard FileManager.default.fileExists(atPath: fileLocation.path) else {
      throw VideoUploadError.localFileMissing
    }
    let chunker = VideoFileChunker(partSizeBytes: configuration.partSizeBytes)
    return BackgroundUploadWakeInput(
      fileLocation: fileLocation,
      chunker: chunker,
      partCount: try chunker.partCount(totalBytes: record.sizeBytes)
    )
  }

  private func prepareBackgroundWakeRecord(
    _ storedRecord: VideoAttachment,
    initialGeneration: Int
  ) async throws -> (record: VideoAttachment, generation: Int) {
    var record = storedRecord
    try requireLiveWakeContext(recordID: record.id, generation: initialGeneration)
    let cancelledLegacyParts = await service.cancelLegacyParts(recordID: record.id)
    try requireLiveWakeContext(recordID: record.id, generation: initialGeneration)

    let generation =
      cancelledLegacyParts
      ? advanceUploadGeneration(recordID: record.id)
      : initialGeneration
    guard cancelledLegacyParts || record.uploadGeneration != generation else {
      return (record, generation)
    }
    record.uploadGeneration = generation
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    try await repository.save(record)
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    return (record, generation)
  }

  private func wakeFailureContextIsLive(recordID: UUID, generation: Int?) -> Bool {
    (try? requireLiveWakeContextIfPresent(recordID: recordID, generation: generation)) != nil
  }

  private func resolveBackgroundWakePlan(
    record: inout VideoAttachment,
    partCount: Int,
    generation: Int
  ) async throws -> BackgroundUploadWakePlanner.Decision {
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    var pendingPartNumbers = await service.pendingPartNumbers(
      recordID: record.id,
      generation: generation
    )
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    var decision = backgroundWakeDecision(record: record, pendingParts: pendingPartNumbers)
    guard decision == .prepareRemoteSession else { return decision }
    guard record.remoteAttachmentID == nil else {
      throw VideoUploadError.partURLCountMismatch(
        expected: partCount,
        received: record.uploadPartTargets.count
      )
    }

    record.status = .uploading
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    try await repository.save(record)
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    record = try await initiate(
      record,
      partCount: partCount,
      wakeGeneration: generation
    )
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    pendingPartNumbers = await service.pendingPartNumbers(
      recordID: record.id,
      generation: generation
    )
    try requireLiveWakeContext(recordID: record.id, generation: generation)
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
    fileLocation: URL,
    generation: Int
  ) async throws -> Int? {
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    switch decision {
    case .complete:
      let completedGeneration = try await completeDuringBackgroundWake(
        record,
        generation: generation
      )
      if let completedGeneration {
        try requireLiveWakeContext(recordID: record.id, generation: completedGeneration)
      }
      return completedGeneration
    case .scheduleParts(let partNumbers):
      try await scheduleBackgroundParts(
        partNumbers,
        record: record,
        chunker: chunker,
        fileLocation: fileLocation,
        generation: generation
      )
      try requireLiveWakeContext(recordID: record.id, generation: generation)
      return nil
    case .waitForScheduledParts:
      return nil
    case .prepareRemoteSession:
      throw VideoUploadError.fileUnreadable
    }
  }

  private func completeDuringBackgroundWake(
    _ record: VideoAttachment,
    generation: Int
  ) async throws -> Int? {
    try requireLiveWakeContext(recordID: record.id, generation: generation)
    guard let remoteID = record.remoteAttachmentID else {
      throw VideoUploadError.fileUnreadable
    }
    let etags = record.uploadedParts
      .sorted { $0.partNumber < $1.partNumber }
      .map { UploadPartETagDTO(partNumber: $0.partNumber, etag: $0.etag) }
    return try await complete(
      record,
      remoteID: remoteID,
      etags: etags,
      wakeGeneration: generation
    )
  }

  private func scheduleBackgroundParts(
    _ partNumbers: [Int],
    record: VideoAttachment,
    chunker: VideoFileChunker,
    fileLocation: URL,
    generation: Int
  ) async throws {
    let targets = Dictionary(
      uniqueKeysWithValues: record.uploadPartTargets.map { ($0.partNumber, $0.url) }
    )
    let chunkDirectory = chunkDirectory(recordID: record.id)
    for partNumber in partNumbers {
      try requireLiveWakeContext(recordID: record.id, generation: generation)
      guard let target = targets[partNumber] else {
        throw VideoUploadError.invalidPartURL(partNumber: partNumber)
      }
      try requireLiveWakeContext(recordID: record.id, generation: generation)
      let partFile = try chunker.writePart(
        partNumber: partNumber,
        from: fileLocation,
        to: chunkDirectory
      )
      try requireLiveWakeContext(recordID: record.id, generation: generation)
      try await service.schedulePart(
        to: target,
        from: partFile,
        identifier: VideoUploadPartIdentifier(
          recordID: record.id,
          partNumber: partNumber,
          generation: generation
        )
      )
      try requireLiveWakeContext(recordID: record.id, generation: generation)
    }
  }

}
