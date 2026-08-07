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
    guard let generation = try? requireLiveSnapshotGeneration(from: record) else {
      return nil
    }
    if await service.cancelLegacyParts(recordID: record.id) {
      guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
        return nil
      }
      return await restartDormantUpload(record, generation: generation)
    }
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
      return nil
    }
    if let firstFailureAt = record.firstUploadFailureAt {
      scheduleRetry(
        record: record,
        firstFailureAt: firstFailureAt,
        networkState: .available,
        generation: generation
      )
      return nil
    }
    let pendingParts = await service.pendingPartNumbers(
      recordID: record.id,
      generation: generation
    )
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil,
      pendingParts.isEmpty
    else { return nil }
    return await restartDormantUpload(record, generation: generation)
  }

  private func restartDormantUpload(
    _ record: VideoAttachment,
    generation: Int
  ) async -> Task<Void, Never>? {
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
      return nil
    }
    guard FileManager.default.fileExists(atPath: fileURL(for: record).path) else {
      await transitionToTerminalFailure(record, generation: generation)
      return nil
    }
    guard (try? requireLiveWakeContext(recordID: record.id, generation: generation)) != nil else {
      return nil
    }
    return startUploadTask(
      recordID: record.id,
      sourceURL: nil,
      previousGeneration: generation
    )
  }
}
