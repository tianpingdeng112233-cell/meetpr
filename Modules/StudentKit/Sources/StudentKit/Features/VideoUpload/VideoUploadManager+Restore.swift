import CoreModels
import Foundation

extension VideoUploadManager {
  /// App-launch recovery reconnects to restored background tasks, resumes any
  /// locally persisted retry window, and finishes complete when all ETags are
  /// already present.
  public func recoverInterruptedUploads(studentID: UUID) async {
    activateBackgroundHandling()
    recoveringStudentIDs.insert(studentID)
    await flushPendingLocalCleanups()
    await cleanTerminalChunkFiles(studentID: studentID)
    await cleanRetainedVideos(studentID: studentID)
    await flushPendingRemoteCleanups()
    guard await !service.isBackgroundWakeActive() else { return }
    _ = await recoverDormantUploads(studentID: studentID)
  }

  func recoverDormantUploads(studentID: UUID) async -> [Task<Void, Never>] {
    let records = (try? await repository.fetchAll(studentID: studentID)) ?? []
    await cleanFailedRemoteSessions(in: records)
    var startedTasks: [Task<Void, Never>] = []
    for record in records where record.status != .uploaded && record.status != .failed {
      if let task = await recoverDormantUpload(record) {
        startedTasks.append(task)
      }
    }
    return startedTasks
  }

  private func cleanFailedRemoteSessions(in records: [VideoAttachment]) async {
    for storedRecord in records
    where storedRecord.status == .failed && storedRecord.remoteAttachmentID != nil {
      guard let generation = try? requireLiveSnapshotGeneration(from: storedRecord) else {
        continue
      }
      var record = storedRecord
      if await abandonRemoteSession(record: &record) {
        guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil
        else {
          continue
        }
        try? await repository.save(record)
        guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil
        else {
          continue
        }
      }
    }
  }

  private func recoverDormantUpload(_ record: VideoAttachment) async -> Task<Void, Never>? {
    guard activeUploads[record.id] == nil, scheduledRetries[record.id] == nil else { return nil }
    guard let previousGeneration = try? requireLiveSnapshotGeneration(from: record) else {
      return nil
    }
    // fetchAll and earlier cleanup calls suspend. A real OS wake that registers
    // during that window owns the URLSession tasks and must win before manual
    // recovery invalidates their generation or cancels them.
    guard await !service.isBackgroundWakeActive() else { return nil }
    // A user-initiated launch has no OS background-session completion handler.
    // URLSession may still enumerate force-quit tasks that can never make
    // forward progress, so pending-task enumeration is not proof of liveness.
    // The service atomically arbitrates cancellation against handler storage.
    // Once manual recovery wins, the harvesting marker keeps wake sweeps away;
    // advancing and persisting the generation before cancellation rejects old
    // callbacks throughout the cancellation await. The replacement pipeline
    // then rebuilds from only the ETags committed before the harvest began.
    guard manualHarvestingRecordIDs.insert(record.id).inserted else { return nil }
    defer { manualHarvestingRecordIDs.remove(record.id) }
    // Claim under the completion-registry lock before committing a generation.
    // A handler that was already registered wins without any local mutation;
    // a later handler cannot revoke this claim while persistence suspends.
    guard let cancellationClaim = await service.claimBackgroundCancellation() else { return nil }
    nextUploadGeneration = max(nextUploadGeneration, previousGeneration)
    let harvestGeneration = advanceUploadGeneration(recordID: record.id)
    guard
      let harvestedRecord = try? await persistUploadGeneration(
        harvestGeneration,
        recordID: record.id
      ),
      (try? requireLiveWakeContext(recordID: record.id, generation: harvestGeneration)) != nil
    else {
      await service.releaseBackgroundCancellationClaim(cancellationClaim)
      return nil
    }
    await service.cancelParts(recordID: record.id, claim: cancellationClaim)
    guard
      (try? requireLiveWakeContext(recordID: record.id, generation: harvestGeneration)) != nil
    else {
      return nil
    }
    if let firstFailureAt = harvestedRecord.firstUploadFailureAt {
      scheduleRetry(
        record: harvestedRecord,
        firstFailureAt: firstFailureAt,
        networkState: .available,
        generation: harvestGeneration
      )
      return nil
    }
    return await restartDormantUpload(harvestedRecord, generation: harvestGeneration)
  }

  private func restartDormantUpload(
    _ record: VideoAttachment,
    generation: Int
  ) async -> Task<Void, Never>? {
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
      return nil
    }
    let exportedFileExists = FileManager.default.fileExists(atPath: fileURL(for: record).path)
    let sourceURL = exportedFileExists ? nil : retainedSourceURL(recordID: record.id)
    guard exportedFileExists || sourceURL != nil else {
      await transitionToTerminalFailure(record, generation: generation)
      return nil
    }
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
      return nil
    }
    return startUploadTask(
      recordID: record.id,
      sourceURL: sourceURL,
      previousGeneration: generation
    )
  }
}
