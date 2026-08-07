import Analytics
import CoreModels
import Foundation
import Networking
import RepositoryContracts

extension VideoUploadManager {
  func run(recordID: UUID, sourceURL: URL?, generation: Int) async {
    defer {
      if let sourceURL {
        try? FileManager.default.removeItem(at: sourceURL)
      }
    }

    do {
      var record = try await persistUploadGeneration(generation, recordID: recordID)
      if let sourceURL {
        record = try await export(record, from: sourceURL)
      }
      if let completedGeneration = try await upload(record, generation: generation) {
        await reclaimUploadGeneration(completedGeneration, recordID: recordID)
      }
    } catch is CancellationError {
      // remove() owns exported-file and part-file cleanup.
    } catch is BackgroundUploadPipelineDeferred {
      // The background-session event consumer persisted this ETag and owns
      // scheduling the next bounded batch during the current wake window.
    } catch {
      await handleUploadFailure(recordID: recordID, error: error, generation: generation)
    }
  }

  private func export(
    _ record: VideoAttachment,
    from sourceURL: URL
  ) async throws -> VideoAttachment {
    try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    let destination = fileURL(for: record)
    try await exporter.export(from: sourceURL, to: destination)

    try Task.checkCancellation()
    guard try await repository.fetch(id: record.id) != nil else {
      try? FileManager.default.removeItem(at: destination)
      throw CancellationError()
    }
    var exported = record
    exported.sizeBytes = try Self.fileSize(at: destination)
    try await repository.save(exported)
    broadcast(.updated(exported, progress: nil))
    return exported
  }

  private func upload(_ record: VideoAttachment, generation: Int) async throws -> Int? {
    let fileLocation = fileURL(for: record)
    guard FileManager.default.fileExists(atPath: fileLocation.path) else {
      throw VideoUploadError.localFileMissing
    }

    var uploading = record
    uploading.status = .uploading
    try await repository.save(uploading)
    broadcast(.updated(uploading, progress: nil))
    Analytics.shared.mediaUpload(
      .started,
      context: .setLog,
      bytes: Int(clamping: uploading.sizeBytes)
    )

    let chunker = VideoFileChunker(partSizeBytes: configuration.partSizeBytes)
    let partCount = try chunker.partCount(totalBytes: uploading.sizeBytes)
    let chunkDirectory = chunkDirectory(recordID: uploading.id)
    try requireCurrentUploadGeneration(generation, recordID: uploading.id)
    _ = try chunker.writeParts(from: fileLocation, to: chunkDirectory)

    if uploading.remoteAttachmentID == nil
      || uploading.uploadPartTargets.count != partCount
      || uploading.uploadPartCount != partCount
    {
      await flushPendingRemoteCleanups()
      uploading = try await initiate(uploading, partCount: partCount)
    }

    guard let remoteID = uploading.remoteAttachmentID else {
      throw VideoUploadError.fileUnreadable
    }
    let etags = try await uploadParts(
      record: uploading,
      chunker: chunker,
      chunkDirectory: chunkDirectory,
      generation: generation
    )
    return try await complete(uploading, remoteID: remoteID, etags: etags)
  }

  func initiate(
    _ record: VideoAttachment,
    partCount: Int,
    wakeGeneration: Int? = nil
  ) async throws -> VideoAttachment {
    try Task.checkCancellation()
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    let response: InitiateUploadResponseDTO
    do {
      response = try await service.initiate(
        InitiateUploadRequestDTO(
          kind: .setVideo,
          contentType: record.contentType,
          sizeBytes: record.sizeBytes,
          partCount: partCount,
          filename: "setlog-\(record.setLogID.uuidString)-\(record.id.uuidString).mp4",
          setLogID: record.setLogID
        )
      )
    } catch {
      try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
      throw error
    }
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    let partURLs = try Self.partURLMap(from: response.partURLs, expectedCount: partCount)
    var initiated = record
    initiated.remoteAttachmentID = response.attachmentID
    initiated.uploadPartCount = partCount
    initiated.uploadPartTargets = partURLs.map { partNumber, url in
      VideoUploadPartTarget(partNumber: partNumber, url: url)
    }.sorted { $0.partNumber < $1.partNumber }
    initiated.uploadedParts = []
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    try await repository.save(initiated)
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    broadcast(.updated(initiated, progress: nil))
    return initiated
  }

  func complete(
    _ record: VideoAttachment,
    remoteID: UUID,
    etags: [UploadPartETagDTO],
    wakeGeneration: Int? = nil
  ) async throws -> Int? {
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    do {
      _ = try await service.complete(attachmentID: remoteID, parts: etags)
    } catch APIError.httpStatus(let statusCode, _) where statusCode == 409 {
      try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
      throw VideoUploadError.completeConflict
    } catch {
      try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
      throw error
    }
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)

    guard try await repository.fetch(id: record.id) != nil else { return nil }
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    var uploaded = record
    uploaded.status = .uploaded
    uploaded.uploadedAt = now()
    uploaded.uploadPartTargets = []
    uploaded.uploadedParts = []
    uploaded.uploadPartCount = 0
    uploaded.uploadRetryCount = 0
    uploaded.firstUploadFailureAt = nil
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    try await repository.save(uploaded)
    try requireLiveWakeContextIfPresent(recordID: record.id, generation: wakeGeneration)
    let cleanupGeneration = await removeChunkFiles(recordID: record.id)
    if wakeGeneration != nil {
      try requireLiveWakeContext(recordID: record.id, generation: cleanupGeneration)
    }
    broadcast(.updated(uploaded, progress: nil))
    Analytics.shared.mediaUpload(
      .succeeded,
      context: .setLog,
      bytes: Int(clamping: record.sizeBytes)
    )
    return cleanupGeneration
  }

  private func uploadParts(
    record: VideoAttachment,
    chunker: VideoFileChunker,
    chunkDirectory: URL,
    generation: Int
  ) async throws -> [UploadPartETagDTO] {
    let completedNumbers = Set(record.uploadedParts.map(\.partNumber))
    let pendingTargets = record.uploadPartTargets.filter {
      !completedNumbers.contains($0.partNumber)
    }

    try await withThrowingTaskGroup(of: VideoUploadedPart.self) { group in
      var iterator = pendingTargets.makeIterator()

      func submitNext() {
        guard let target = iterator.next() else { return }
        group.addTask {
          try await self.uploadPart(
            target,
            recordID: record.id,
            chunker: chunker,
            chunkDirectory: chunkDirectory,
            generation: generation
          )
        }
      }

      for _ in 0..<min(configuration.maxConcurrentParts, pendingTargets.count) {
        submitNext()
      }
      do {
        for try await part in group {
          try requireCurrentUploadGeneration(generation, recordID: record.id)
          try await persist(part: part, recordID: record.id)
          submitNext()
        }
      } catch is BackgroundUploadPipelineDeferred {
        group.cancelAll()
        throw BackgroundUploadPipelineDeferred()
      } catch {
        group.cancelAll()
        await service.cancelParts(recordID: record.id)
        throw error
      }
    }

    guard let latest = try await repository.fetch(id: record.id),
      latest.uploadedParts.count == latest.uploadPartCount
    else {
      throw VideoUploadError.fileUnreadable
    }
    return latest.uploadedParts
      .sorted { $0.partNumber < $1.partNumber }
      .map { UploadPartETagDTO(partNumber: $0.partNumber, etag: $0.etag) }
  }

  private func uploadPart(
    _ target: VideoUploadPartTarget,
    recordID: UUID,
    chunker: VideoFileChunker,
    chunkDirectory: URL,
    generation: Int
  ) async throws -> VideoUploadedPart {
    let partFile = chunker.partFileURL(partNumber: target.partNumber, in: chunkDirectory)
    let etag = try await service.uploadPart(
      to: target.url,
      from: partFile,
      identifier: VideoUploadPartIdentifier(
        recordID: recordID,
        partNumber: target.partNumber,
        generation: generation
      )
    )
    try requireCurrentUploadGeneration(generation, recordID: recordID)
    return VideoUploadedPart(partNumber: target.partNumber, etag: etag)
  }

  func persist(part: VideoUploadedPart, recordID: UUID) async throws {
    guard var latest = try await repository.fetch(id: recordID) else {
      throw CancellationError()
    }
    latest.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    latest.uploadedParts.append(part)
    latest.uploadedParts.sort { $0.partNumber < $1.partNumber }
    try await repository.save(latest)
    let progress =
      latest.uploadPartCount > 0
      ? Double(latest.uploadedParts.count) / Double(latest.uploadPartCount)
      : nil
    broadcast(.updated(latest, progress: progress))
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
