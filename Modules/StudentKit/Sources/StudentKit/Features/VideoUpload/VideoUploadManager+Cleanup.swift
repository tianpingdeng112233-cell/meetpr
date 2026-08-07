import CoreModels
import Foundation
import Networking

struct VideoChunkCleanupResult: Sendable {
  let generation: Int
  let isDurable: Bool
}

extension VideoUploadManager {
  /// Cancels any in-flight upload, abandons an unfinished remote upload, and
  /// deletes all local record, video, and chunk files. A ready attachment is
  /// only unlinked locally because the upload abort endpoint rejects it.
  public func remove(attachmentID: UUID) async {
    // The teardown below clears the active/retry markers before the record
    // row disappears; a cancelParts-triggered session-finished sweep must not
    // treat that intermediate state as dormant and revive the upload.
    guard removingRecordIDs.insert(attachmentID).inserted else { return }
    defer { removingRecordIDs.remove(attachmentID) }
    await persistNewUploadGeneration(recordID: attachmentID)
    if let task = activeUploads[attachmentID] {
      task.cancel()
      activeUploads[attachmentID] = nil
      activeUploadOwnerships[attachmentID] = nil
    }
    scheduledRetries[attachmentID]?.cancel()
    scheduledRetries[attachmentID] = nil
    scheduledRetryGenerations[attachmentID] = nil
    await service.cancelParts(recordID: attachmentID)
    guard var record = try? await repository.fetch(id: attachmentID) else { return }

    if record.status != .uploaded {
      guard await abandonRemoteSession(record: &record) else { return }
    }
    guard await removeLocalFileOrPersistCleanupIntent(record) else { return }
    guard await removeChunkFiles(recordID: attachmentID).isDurable else { return }
    do {
      try await repository.delete(id: attachmentID)
    } catch {
      return
    }
    // Keep one monotonic tombstone per deleted record. Any suspended fetch or
    // fetchAll snapshot still carries an older persisted generation, so it can
    // never pass snapshot validation or reseed the in-memory authority.
    advanceUploadGeneration(recordID: attachmentID)
    broadcast(.removed(setLogID: record.setLogID, attachmentID: attachmentID))
  }

  func fileURL(for record: VideoAttachment) -> URL {
    filesDirectory.appendingPathComponent(record.localFileName ?? "\(record.id.uuidString).mp4")
  }

  func chunkDirectory(recordID: UUID) -> URL {
    filesDirectory.appending(path: "\(recordID.uuidString).parts", directoryHint: .isDirectory)
  }

  @discardableResult
  func removeChunkFiles(recordID: UUID) async -> VideoChunkCleanupResult {
    let generation = await persistNewUploadGeneration(recordID: recordID)
    let directory = chunkDirectory(recordID: recordID)
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return VideoChunkCleanupResult(generation: generation, isDurable: true)
    }
    let directoryName = directory.lastPathComponent

    do {
      try await localCleanupStore.enqueue(directoryName)
    } catch {
      do {
        try removeLocalFile(directory)
        return VideoChunkCleanupResult(generation: generation, isDurable: true)
      } catch {
        return VideoChunkCleanupResult(generation: generation, isDurable: false)
      }
    }

    do {
      try removeLocalFile(directory)
      try? await localCleanupStore.remove(directoryName)
    } catch {}
    return VideoChunkCleanupResult(generation: generation, isDurable: true)
  }

  func cleanTerminalChunkFiles(studentID: UUID) async {
    let records = (try? await repository.fetchAll(studentID: studentID)) ?? []
    for record in records where record.status == .uploaded || record.status == .failed {
      let directory = chunkDirectory(recordID: record.id)
      guard FileManager.default.fileExists(atPath: directory.path) else { continue }
      _ = await removeChunkFiles(recordID: record.id)
    }
  }

  /// Mirrors the remote-abort queue: once the file name is durable, the local
  /// record can be forgotten even if the immediate unlink fails. If neither
  /// persistence nor deletion succeeds, the record remains the cleanup owner.
  func removeLocalFileOrPersistCleanupIntent(_ record: VideoAttachment) async -> Bool {
    let url = fileURL(for: record)
    guard FileManager.default.fileExists(atPath: url.path) else { return true }
    let fileName = url.lastPathComponent

    do {
      try await localCleanupStore.enqueue(fileName)
    } catch {
      do {
        try removeLocalFile(url)
        return true
      } catch {
        return false
      }
    }

    do {
      try removeLocalFile(url)
      try? await localCleanupStore.remove(fileName)
    } catch {}
    return true
  }

  func flushPendingLocalCleanups() async {
    let fileNames = (try? await localCleanupStore.pendingFileNames()) ?? []
    for fileName in fileNames {
      let url = filesDirectory.appending(path: fileName)
      if FileManager.default.fileExists(atPath: url.path) {
        do {
          try removeLocalFile(url)
        } catch {
          continue
        }
      }
      try? await localCleanupStore.remove(fileName)
    }
  }

  func cleanRetainedVideos(studentID: UUID) async {
    let records = (try? await repository.fetchAll(studentID: studentID)) ?? []
    let retainedFiles = records.compactMap { record -> RetainedVideoFile? in
      guard let localFileName = record.localFileName else { return nil }
      let url = filesDirectory.appending(path: localFileName)
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
      let sizeBytes = attributes?[.size] as? Int64 ?? 0
      return RetainedVideoFile(
        attachmentID: record.id,
        status: record.status,
        trainingDate: record.trainingDate,
        recordedAt: record.recordedAt,
        sizeBytes: sizeBytes
      )
    }
    let removals = RetainedVideoCleanupPolicy.attachmentIDsToRemove(
      from: retainedFiles,
      now: now(),
      calendar: .autoupdatingCurrent
    )

    for record in records where removals.contains(record.id) {
      guard let localFileName = record.localFileName else { continue }
      let url = filesDirectory.appending(path: localFileName)
      if FileManager.default.fileExists(atPath: url.path) {
        do {
          try FileManager.default.removeItem(at: url)
        } catch {
          continue
        }
      }
      var cleaned = record
      cleaned.localFileName = nil
      try? await repository.save(cleaned)
      broadcast(.updated(cleaned, progress: nil))
    }
  }

  func resetRemoteSession(on record: inout VideoAttachment) {
    record.remoteAttachmentID = nil
    record.uploadPartCount = 0
    record.uploadPartTargets = []
    record.uploadedParts = []
  }

  /// Persists cleanup intent before the local attachment forgets the remote
  /// identifier. If both queue persistence and the immediate abort fail, the
  /// caller retains the identifier and can try again later.
  @discardableResult
  func abandonRemoteSession(record: inout VideoAttachment) async -> Bool {
    guard let remoteID = record.remoteAttachmentID else {
      resetRemoteSession(on: &record)
      return true
    }
    do {
      try await cleanupStore.enqueue(remoteID)
    } catch {
      do {
        try await service.abort(attachmentID: remoteID)
        resetRemoteSession(on: &record)
        return true
      } catch {
        return false
      }
    }
    do {
      try await service.abort(attachmentID: remoteID)
      try? await cleanupStore.remove(remoteID)
    } catch {}
    resetRemoteSession(on: &record)
    return true
  }

  func flushPendingRemoteCleanups() async {
    let identifiers = (try? await cleanupStore.pendingAttachmentIDs()) ?? []
    for identifier in identifiers {
      do {
        try await service.abort(attachmentID: identifier)
        try await cleanupStore.remove(identifier)
      } catch let error as APIError where Self.isRemoteCleanupTerminal(error) {
        try? await cleanupStore.remove(identifier)
      } catch {}
    }
  }

  static func isRemoteCleanupTerminal(_ error: APIError) -> Bool {
    if case .httpStatus(let statusCode, _) = error {
      return statusCode == 404 || statusCode == 409
    }
    return false
  }
}
