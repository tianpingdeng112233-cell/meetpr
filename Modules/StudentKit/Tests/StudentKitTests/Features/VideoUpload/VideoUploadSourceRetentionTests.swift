import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func uploadManagerDeletesRetainedSourceAfterSuccess() async throws {
  let harness = VideoUploadHarness()
  let sourceURL = try makeTemporaryVideoSource()

  let record = try await harness.manager.enqueue(
    sourceURL: sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  // The record reaches `.uploaded` one step before the retained source is
  // swept, so poll for the sweep instead of assuming it already ran.
  try await waitUntil { await harness.manager.retainedSourceURL(recordID: record.id) == nil }

  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func uploadManagerRetainsManagedSourceAfterExportFailure() async throws {
  let harness = VideoUploadHarness(exporter: FailingVideoExporter())
  let sourceURL = try makeTemporaryVideoSource()

  let record = try await harness.manager.enqueue(
    sourceURL: sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])

  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
  let retainedSource = try #require(await harness.manager.retainedSourceURL(recordID: record.id))
  #expect(FileManager.default.fileExists(atPath: retainedSource.path))
}

@Test func retryReexportsFromRetainedSourceWhenExportedFileIsMissing() async throws {
  let exporter = RecoveringVideoExporter()
  let harness = VideoUploadHarness(exporter: exporter)

  let record = try await harness.manager.enqueue(
    sourceURL: harness.sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.failed])
  let retainedSource = try #require(await harness.manager.retainedSourceURL(recordID: record.id))
  #expect(FileManager.default.fileExists(atPath: retainedSource.path))
  #expect(!FileManager.default.fileExists(atPath: await harness.manager.fileURL(for: record).path))

  await exporter.allowExports()
  await harness.manager.retry(attachmentID: record.id)
  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  try await waitUntil { !FileManager.default.fileExists(atPath: retainedSource.path) }

  #expect(await exporter.exportAttempts > 1)
}

@Test func coldStartCleanupDeletesUploadedAndOrphanSourceFiles() async throws {
  let harness = VideoUploadHarness()
  let studentID = UUID()
  let uploaded = sourceRetentionRecord(studentID: studentID, status: .uploaded)
  try await harness.repository.save(uploaded)
  let uploadedSource = await harness.manager.sourceFileURL(
    recordID: uploaded.id,
    pathExtension: "mov"
  )
  let orphanSource = await harness.manager.sourceFileURL(
    recordID: UUID(),
    pathExtension: "mp4"
  )
  try Data([0x01]).write(to: uploadedSource)
  try Data([0x02]).write(to: orphanSource)

  await harness.manager.recoverInterruptedUploads(studentID: studentID)

  #expect(!FileManager.default.fileExists(atPath: uploadedSource.path))
  #expect(!FileManager.default.fileExists(atPath: orphanSource.path))
}

@Test func cleanupDoesNotMistakeAnotherStudentsFailedSourceForAnOrphan() async throws {
  let harness = VideoUploadHarness()
  let currentStudentID = UUID()
  let otherStudentRecord = sourceRetentionRecord(studentID: UUID(), status: .failed)
  try await harness.repository.save(otherStudentRecord)
  let sourceURL = await harness.manager.sourceFileURL(
    recordID: otherStudentRecord.id,
    pathExtension: "mov"
  )
  try Data([0x01]).write(to: sourceURL)

  await harness.manager.recoverInterruptedUploads(studentID: currentStudentID)

  #expect(FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func coldStartFlushesDurableSourceCleanupIntent() async throws {
  let harness = VideoUploadHarness()
  let cleanupStore = LocalVideoCleanupStore(
    fileURL: harness.filesDirectory.appending(path: "pending-local-cleanup.json")
  )
  let sourceURL = await harness.manager.sourceFileURL(
    recordID: UUID(),
    pathExtension: "mov"
  )
  try Data([0x01]).write(to: sourceURL)
  try await cleanupStore.enqueue(sourceURL.lastPathComponent)

  await harness.manager.recoverInterruptedUploads(studentID: UUID())

  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
  let restartedStore = LocalVideoCleanupStore(
    fileURL: harness.filesDirectory.appending(path: "pending-local-cleanup.json")
  )
  #expect(try await restartedStore.pendingFileNames().isEmpty)
}

@Test func cleanupSparesMovedSourceWhoseRecordIsNotYetSaved() async throws {
  let repository = EnqueuePendingSaveGatedRepository()
  let filesDirectory = FileManager.default.temporaryDirectory
    .appending(path: "source-retention-gate-\(UUID().uuidString)", directoryHint: .isDirectory)
  let manager = VideoUploadManager(
    service: MockVideoUploadService(),
    exporter: FailingVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory,
    retryScheduler: UploadRetryScheduler(backoffSeconds: [0], timeBoxSeconds: 30 * 60)
  )
  let studentID = UUID()
  let sourceURL = try makeTemporaryVideoSource()
  await repository.pauseNextPendingSave()

  let enqueueTask = Task {
    try await manager.enqueue(sourceURL: sourceURL, setLogID: UUID(), studentID: studentID)
  }
  try await waitUntil { await repository.pendingSaveStarted }
  // The source has been moved into filesDirectory but its record is not
  // persisted yet — only `retainingSourceRecordIDs` protects it here.
  let movedSources = try sourceFileURLs(in: filesDirectory)
  #expect(movedSources.count == 1)

  await manager.cleanRetainedVideos(studentID: studentID)
  #expect(try sourceFileURLs(in: filesDirectory) == movedSources)

  await repository.releasePendingSave()
  let record = try await enqueueTask.value
  _ = try await waitForStatus(repository, id: record.id, oneOf: [.failed])
  #expect(await manager.retainedSourceURL(recordID: record.id) != nil)
}

@Test func enqueueLeavesNoResidueWhenFirstSaveThrows() async throws {
  let repository = FailingFirstSaveRepository()
  let filesDirectory = FileManager.default.temporaryDirectory
    .appending(path: "source-retention-throw-\(UUID().uuidString)", directoryHint: .isDirectory)
  let manager = VideoUploadManager(
    service: MockVideoUploadService(),
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory,
    retryScheduler: UploadRetryScheduler(backoffSeconds: [0], timeBoxSeconds: 30 * 60)
  )
  let studentID = UUID()
  let sourceURL = try makeTemporaryVideoSource()

  await #expect(throws: (any Error).self) {
    try await manager.enqueue(sourceURL: sourceURL, setLogID: UUID(), studentID: studentID)
  }

  #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
  #expect(try sourceFileURLs(in: filesDirectory).isEmpty)
  #expect(try await repository.fetchAll(studentID: studentID).isEmpty)
}

private func sourceFileURLs(in directory: URL) throws -> [URL] {
  let urls =
    (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )) ?? []
  return
    urls
    .filter { $0.lastPathComponent.contains(".source.") }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

private actor EnqueuePendingSaveGatedRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment] = [:]
  private var pausesPendingSave = false
  private var pendingSaveContinuation: CheckedContinuation<Void, Never>?
  private(set) var pendingSaveStarted = false

  func pauseNextPendingSave() {
    pausesPendingSave = true
  }

  func releasePendingSave() {
    pendingSaveContinuation?.resume()
    pendingSaveContinuation = nil
  }

  func save(_ attachment: VideoAttachment) async throws {
    if pausesPendingSave, attachment.status == .pending, storage[attachment.id] == nil {
      pendingSaveStarted = true
      await withCheckedContinuation { continuation in
        pendingSaveContinuation = continuation
      }
      pausesPendingSave = false
    }
    storage[attachment.id] = attachment
  }

  func persistUploadedPart(
    _ part: VideoUploadedPart,
    recordID: UUID,
    expectedUploadGeneration: Int
  ) -> VideoAttachment? {
    guard var attachment = storage[recordID],
      attachment.uploadGeneration == expectedUploadGeneration
    else { return nil }
    attachment.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    attachment.uploadedParts.append(part)
    attachment.uploadedParts.sort { $0.partNumber < $1.partNumber }
    storage[recordID] = attachment
    return attachment
  }

  func fetch(id: UUID) -> VideoAttachment? {
    storage[id]
  }

  func fetch(setLogID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.setLogID == setLogID }
  }

  func fetchAll(studentID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.studentID == studentID }
  }

  func delete(id: UUID) {
    storage[id] = nil
  }

  func playbackURL(for attachment: VideoAttachment) -> URL? {
    nil
  }
}

private actor FailingFirstSaveRepository: VideoAttachmentRepository {
  private struct FirstSaveError: Error {}
  private var storage: [UUID: VideoAttachment] = [:]
  private var hasFailedFirstSave = false

  func save(_ attachment: VideoAttachment) async throws {
    if !hasFailedFirstSave {
      hasFailedFirstSave = true
      throw FirstSaveError()
    }
    storage[attachment.id] = attachment
  }

  func persistUploadedPart(
    _ part: VideoUploadedPart,
    recordID: UUID,
    expectedUploadGeneration: Int
  ) -> VideoAttachment? {
    guard var attachment = storage[recordID],
      attachment.uploadGeneration == expectedUploadGeneration
    else { return nil }
    attachment.uploadedParts.removeAll { $0.partNumber == part.partNumber }
    attachment.uploadedParts.append(part)
    attachment.uploadedParts.sort { $0.partNumber < $1.partNumber }
    storage[recordID] = attachment
    return attachment
  }

  func fetch(id: UUID) -> VideoAttachment? {
    storage[id]
  }

  func fetch(setLogID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.setLogID == setLogID }
  }

  func fetchAll(studentID: UUID) -> [VideoAttachment] {
    storage.values.filter { $0.studentID == studentID }
  }

  func delete(id: UUID) {
    storage[id] = nil
  }

  func playbackURL(for attachment: VideoAttachment) -> URL? {
    nil
  }
}

private func sourceRetentionRecord(
  studentID: UUID,
  status: VideoAttachment.Status
) -> VideoAttachment {
  VideoAttachment(
    id: UUID(),
    setLogID: UUID(),
    studentID: studentID,
    remoteAttachmentID: status == .pending ? nil : UUID(),
    status: status,
    contentType: "video/mp4",
    durationSeconds: 30,
    sizeBytes: 1_000,
    localFileName: "file.mp4",
    recordedAt: Date(),
    uploadedAt: status == .uploaded ? Date() : nil
  )
}
