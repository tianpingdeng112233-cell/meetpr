import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func terminalFailurePersistsFailedBeforeQueuedChunkCleanup() async throws {
  let service = MockVideoUploadService()
  let repository = InMemoryVideoAttachmentRepository()
  let filesDirectory = chunkCleanupDirectory(prefix: "queued")
  let cleanupFile = filesDirectory.appending(path: "pending-local-cleanup.json")
  let cleanupStore = LocalVideoCleanupStore(fileURL: cleanupFile)
  let record = makeChunkCleanupRecord(status: .uploading)
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  try await repository.save(record)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory,
    localCleanupStore: cleanupStore,
    removeLocalFile: { url in
      if url.lastPathComponent.hasSuffix(".parts") {
        throw ChunkCleanupTestError.forcedFailure
      }
      try FileManager.default.removeItem(at: url)
    }
  )
  let generation = await manager.advanceUploadGeneration(recordID: record.id)

  await manager.transitionToTerminalFailure(record, generation: generation)

  #expect(try await repository.fetch(id: record.id)?.status == .failed)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(try await cleanupStore.pendingFileNames() == [chunkDirectory.lastPathComponent])

  let restartedStore = LocalVideoCleanupStore(fileURL: cleanupFile)
  let restartedManager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory,
    localCleanupStore: restartedStore
  )
  await restartedManager.recoverInterruptedUploads(studentID: record.studentID)

  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(try await restartedStore.pendingFileNames().isEmpty)
}

@Test func terminalFailureDoesNotDependOnDurableChunkCleanup() async throws {
  let service = MockVideoUploadService()
  let repository = InMemoryVideoAttachmentRepository()
  let filesDirectory = chunkCleanupDirectory(prefix: "rejected")
  let record = makeChunkCleanupRecord(status: .uploading)
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  try await repository.save(record)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory,
    localCleanupStore: RejectingLocalVideoCleanupStore(),
    removeLocalFile: { _ in throw ChunkCleanupTestError.forcedFailure }
  )
  let generation = await manager.advanceUploadGeneration(recordID: record.id)

  await manager.transitionToTerminalFailure(record, generation: generation)

  #expect(try await repository.fetch(id: record.id)?.status == .failed)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))
}

@Test func launchRecoveryRemovesUnqueuedFailedChunkOrphan() async throws {
  let service = MockVideoUploadService()
  let repository = InMemoryVideoAttachmentRepository()
  let filesDirectory = chunkCleanupDirectory(prefix: "orphan")
  let record = makeChunkCleanupRecord(status: .failed)
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  try await repository.save(record)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory
  )

  await manager.recoverInterruptedUploads(studentID: record.studentID)

  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(try await repository.fetch(id: record.id)?.status == .failed)
}

@Test func launchRecoveryRemovesUnqueuedUploadedChunkOrphan() async throws {
  let service = MockVideoUploadService()
  let repository = InMemoryVideoAttachmentRepository()
  let filesDirectory = chunkCleanupDirectory(prefix: "uploaded-orphan")
  let record = makeChunkCleanupRecord(status: .uploaded)
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  try await repository.save(record)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory
  )

  await manager.recoverInterruptedUploads(studentID: record.studentID)

  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(try await repository.fetch(id: record.id)?.status == .uploaded)
}

@Test func coldStartReconcilesComplete409AfterTerminalSaveInterruption() async throws {
  let service = MockVideoUploadService()
  let recordID = UUID()
  let filesDirectory = chunkCleanupDirectory(prefix: "complete-crash")
  let fileName = "\(recordID.uuidString).mp4"
  let record = try makeCompleteCrashRecord(
    id: recordID,
    remoteID: service.remoteAttachmentID,
    fileName: fileName
  )
  let repository = FailFirstTerminalSaveRepository(record: record, status: .uploaded)
  try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
  try Data(repeating: 0xAB, count: 1_024).write(
    to: filesDirectory.appending(path: fileName)
  )
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  _ = await manager.restoreUploadGeneration(from: record)
  let etags = [UploadPartETagDTO(partNumber: 1, etag: "etag-1")]

  await #expect(throws: TerminalSaveTestError.forcedFailure) {
    _ = try await manager.complete(record, remoteID: service.remoteAttachmentID, etags: etags)
  }
  #expect(await repository.fetch(id: record.id)?.status == .uploading)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))

  await service.setCompleteError(VideoUploadCompleteConflict(status: .ready))
  let restartedManager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  await restartedManager.recoverInterruptedUploads(studentID: record.studentID)

  _ = try await waitForStatus(repository, id: record.id, oneOf: [.uploaded])
  try await waitUntil { !FileManager.default.fileExists(atPath: chunkDirectory.path) }
  #expect(await service.calls.filter { $0 == "complete:1" }.count == 2)
}

@Test func coldStartRetriesFailedTerminalSaveBeforeChunkCleanup() async throws {
  let service = MockVideoUploadService()
  let filesDirectory = chunkCleanupDirectory(prefix: "failure-crash")
  let record = makeChunkCleanupRecord(status: .uploading, uploadGeneration: 1)
  let repository = FailFirstTerminalSaveRepository(record: record, status: .failed)
  let chunkDirectory = try writeChunkCleanupFixture(record: record, filesDirectory: filesDirectory)
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory
  )
  let generation = try #require(await manager.restoreUploadGeneration(from: record))

  await manager.transitionToTerminalFailure(record, generation: generation)

  #expect(await repository.fetch(id: record.id)?.status == .uploading)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))

  let restartedManager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    filesDirectory: filesDirectory
  )
  await restartedManager.recoverInterruptedUploads(studentID: record.studentID)

  _ = try await waitForStatus(repository, id: record.id, oneOf: [.failed])
  try await waitUntil { !FileManager.default.fileExists(atPath: chunkDirectory.path) }
}

private func chunkCleanupDirectory(prefix: String) -> URL {
  FileManager.default.temporaryDirectory.appending(
    path: "video-upload-chunk-cleanup-\(prefix)-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
}

private func makeChunkCleanupRecord(
  status: VideoAttachment.Status,
  uploadGeneration: Int? = nil
) -> VideoAttachment {
  VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: UUID(),
    status: status,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 1_024,
    localFileName: nil,
    recordedAt: Date(),
    uploadGeneration: uploadGeneration
  )
}

private func makeCompleteCrashRecord(
  id: UUID,
  remoteID: UUID,
  fileName: String
) throws -> VideoAttachment {
  let targetURL = try #require(URL(string: "https://oss.test/parts/1"))
  return VideoAttachment(
    id: id,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: remoteID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 1_024,
    localFileName: fileName,
    recordedAt: Date(),
    uploadPartCount: 1,
    uploadPartTargets: [VideoUploadPartTarget(partNumber: 1, url: targetURL)],
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")],
    uploadGeneration: 1
  )
}

private func writeChunkCleanupFixture(
  record: VideoAttachment,
  filesDirectory: URL
) throws -> URL {
  let directory = filesDirectory.appending(
    path: "\(record.id.uuidString).parts",
    directoryHint: .isDirectory
  )
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data([0xAB]).write(to: directory.appending(path: "part-1.chunk"))
  return directory
}

private actor RejectingLocalVideoCleanupStore: LocalVideoCleanupStoring {
  func enqueue(_ fileName: String) throws {
    throw ChunkCleanupTestError.forcedFailure
  }

  func remove(_ fileName: String) throws {}

  func pendingFileNames() throws -> Set<String> {
    []
  }
}

private enum ChunkCleanupTestError: Error {
  case forcedFailure
}

private enum TerminalSaveTestError: Error {
  case forcedFailure
}

private actor FailFirstTerminalSaveRepository: VideoAttachmentRepository {
  private var record: VideoAttachment
  private let status: VideoAttachment.Status
  private var shouldFail = true

  init(record: VideoAttachment, status: VideoAttachment.Status) {
    self.record = record
    self.status = status
  }

  func save(_ attachment: VideoAttachment) throws {
    if attachment.status == status, shouldFail {
      shouldFail = false
      throw TerminalSaveTestError.forcedFailure
    }
    record = attachment
  }

  func persistUploadedPart(
    _ part: VideoUploadedPart,
    recordID: UUID,
    expectedUploadGeneration: Int
  ) -> VideoAttachment? {
    guard record.id == recordID,
      record.uploadGeneration == expectedUploadGeneration
    else { return nil }
    record.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    record.uploadedParts.append(part)
    record.uploadedParts.sort { $0.partNumber < $1.partNumber }
    return record
  }

  func fetch(id: UUID) -> VideoAttachment? {
    record.id == id ? record : nil
  }

  func fetch(setLogID: UUID) -> [VideoAttachment] {
    record.setLogID == setLogID ? [record] : []
  }

  func fetchAll(studentID: UUID) -> [VideoAttachment] {
    record.studentID == studentID ? [record] : []
  }

  func delete(id: UUID) {}

  func playbackURL(for attachment: VideoAttachment) -> URL? {
    nil
  }
}
