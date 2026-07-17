import CoreModels
import Foundation
import Networking
import RepositoryContracts

// The export → chunk → initiate → part PUTs → complete pipeline. Split out of
// VideoUploadManager.swift to keep the actor body within lint budgets; every
// method here is actor-isolated.
extension VideoUploadManager {
  /// Entry point of the per-attachment upload task. `sourceURL` is non-nil on
  /// first run (export still needed) and nil on retries (exported file kept).
  func run(recordID: UUID, sourceURL: URL?) async {
    defer {
      if let sourceURL {
        try? FileManager.default.removeItem(at: sourceURL)
      }
    }

    guard var record = try? await repository.fetch(id: recordID) else {
      return
    }
    do {
      if let sourceURL {
        record = try await export(record, from: sourceURL)
      }
      try await upload(record)
    } catch is CancellationError {
      // remove() owns exported-file cleanup; this method owns source cleanup.
    } catch {
      await markFailed(recordID: recordID, error: error)
    }
  }

  private func export(
    _ record: VideoAttachment,
    from sourceURL: URL
  ) async throws -> VideoAttachment {
    try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    let destination = fileURL(for: record)
    try await exporter.export(from: sourceURL, to: destination)
    SecureLocalStorage.harden(destination)

    try Task.checkCancellation()
    guard try await repository.fetch(id: record.id) != nil else {
      // Removed while exporting: don't resurrect, clean the output.
      try? FileManager.default.removeItem(at: destination)
      throw CancellationError()
    }
    var exported = record
    exported.sizeBytes = try Self.fileSize(at: destination)
    try await repository.save(exported)
    broadcast(.updated(exported, progress: 0))
    return exported
  }

  private func upload(_ record: VideoAttachment) async throws {
    let fileLocation = fileURL(for: record)
    guard FileManager.default.fileExists(atPath: fileLocation.path) else {
      throw VideoUploadError.localFileMissing
    }

    var uploading = record
    uploading.status = .uploading
    try await repository.save(uploading)
    broadcast(.updated(uploading, progress: 0))

    let chunker = VideoFileChunker(partSizeBytes: configuration.partSizeBytes)
    let partCount = try chunker.partCount(totalBytes: uploading.sizeBytes)

    try Task.checkCancellation()
    // set_log_id is the server-side association (backend spec 007); the
    // filename stays human-readable only.
    let response = try await service.initiate(
      InitiateUploadRequestDTO(
        kind: .setVideo,
        contentType: uploading.contentType,
        sizeBytes: uploading.sizeBytes,
        partCount: partCount,
        filename: "setlog-\(uploading.setLogID.uuidString)-\(uploading.id.uuidString).mp4",
        setLogID: uploading.setLogID
      )
    )
    try Task.checkCancellation()
    uploading.remoteAttachmentID = response.attachmentID
    try await repository.save(uploading)
    broadcast(.updated(uploading, progress: 0))

    let partURLs = try Self.partURLMap(from: response.partURLs, expectedCount: partCount)
    let etags = try await uploadParts(
      record: uploading,
      fileLocation: fileLocation,
      chunker: chunker,
      partURLs: partURLs
    )

    try await complete(uploading, remoteID: response.attachmentID, etags: etags)
  }

  private func complete(
    _ record: VideoAttachment,
    remoteID: UUID,
    etags: [UploadPartETagDTO]
  ) async throws {
    do {
      _ = try await service.complete(attachmentID: remoteID, parts: etags)
    } catch APIError.httpStatus(let statusCode, _) where statusCode == 409 {
      throw VideoUploadError.completeConflict
    }

    // A concurrent remove() may have deleted the record while we were on the
    // wire; saving now would resurrect it as a ghost (Codex review P1).
    guard try await repository.fetch(id: record.id) != nil else { return }

    var uploaded = record
    uploaded.status = .uploaded
    uploaded.uploadedAt = now()
    // The exported file served its purpose; keeping it leaks 15-200MB per
    // video (Codex review P1). Playback uses the backend presigned URL.
    uploaded.localFileName = nil
    try await repository.save(uploaded)
    try? FileManager.default.removeItem(at: fileURL(for: record))
    broadcast(.updated(uploaded, progress: 1))
  }

  private func uploadParts(
    record: VideoAttachment,
    fileLocation: URL,
    chunker: VideoFileChunker,
    partURLs: [Int: URL]
  ) async throws -> [UploadPartETagDTO] {
    let partCount = partURLs.count
    var etags: [UploadPartETagDTO] = []
    etags.reserveCapacity(partCount)

    try await withThrowingTaskGroup(of: UploadPartETagDTO.self) { group in
      var nextPart = 1
      func submitNext() throws {
        guard nextPart <= partCount else { return }
        let partNumber = nextPart
        nextPart += 1
        guard let url = partURLs[partNumber] else {
          throw VideoUploadError.invalidPartURL(partNumber: partNumber)
        }
        group.addTask {
          try await self.uploadSinglePart(
            partNumber: partNumber,
            url: url,
            fileLocation: fileLocation,
            chunker: chunker
          )
        }
      }

      for _ in 0..<min(configuration.maxConcurrentParts, partCount) {
        try submitNext()
      }
      for try await etag in group {
        etags.append(etag)
        broadcast(.updated(record, progress: Double(etags.count) / Double(partCount)))
        try submitNext()
      }
    }
    return etags.sorted { $0.partNumber < $1.partNumber }
  }

  /// One part PUT with `configuration.partRetryCount` retries. Runs inside a
  /// task-group child; nonisolated so concurrent parts never serialize on the
  /// actor.
  nonisolated private func uploadSinglePart(
    partNumber: Int,
    url: URL,
    fileLocation: URL,
    chunker: VideoFileChunker
  ) async throws -> UploadPartETagDTO {
    let data = try chunker.readPart(partNumber: partNumber, from: fileLocation)
    var attempt = 0
    while true {
      try Task.checkCancellation()
      do {
        let etag = try await service.uploadPart(to: url, data: data)
        return UploadPartETagDTO(partNumber: partNumber, etag: etag)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        attempt += 1
        guard attempt <= configuration.partRetryCount else { throw error }
        if configuration.partRetryDelay > .zero {
          try await Task.sleep(for: configuration.partRetryDelay)
        }
      }
    }
  }

  private func markFailed(recordID: UUID, error: Error) async {
    // A remove() racing this task already tore the record down — don't
    // resurrect it from a stale failure.
    if Task.isCancelled { return }
    guard var record = try? await repository.fetch(id: recordID) else {
      return
    }

    // Failure can occur after the backend accepted an attachment. Delete it,
    // rather than only aborting multipart work, so no orphaned private object
    // remains. Preserve the id if the deletion itself cannot be confirmed.
    if let remoteID = record.remoteAttachmentID {
      do {
        try await service.delete(attachmentID: remoteID)
        record.remoteAttachmentID = nil
      } catch {
        // A later retry/remove will attempt the same remote deletion again.
      }
    }
    record.status = .failed
    try? await repository.save(record)
    broadcast(.updated(record, progress: nil))
  }

  static func partURLMap(
    from dtos: [UploadPartURLDTO],
    expectedCount: Int
  ) throws -> [Int: URL] {
    guard dtos.count == expectedCount else {
      throw VideoUploadError.partURLCountMismatch(expected: expectedCount, received: dtos.count)
    }
    var map: [Int: URL] = [:]
    for dto in dtos {
      guard let url = URL(string: dto.url) else {
        throw VideoUploadError.invalidPartURL(partNumber: dto.partNumber)
      }
      // Count alone hides duplicates/out-of-range numbers, which would
      // silently truncate the upload (Codex review P2).
      guard (1...expectedCount).contains(dto.partNumber), map[dto.partNumber] == nil else {
        throw VideoUploadError.invalidPartURL(partNumber: dto.partNumber)
      }
      map[dto.partNumber] = url
    }
    return map
  }

  private static func fileSize(at url: URL) throws -> Int64 {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? Int64, size > 0 else {
      throw VideoUploadError.emptyFile
    }
    return size
  }
}
