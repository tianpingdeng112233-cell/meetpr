import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func terminalTeardownInvalidatesSuspendedRecoveryChunkWriter() async throws {
  let notifier = RecordingUploadFailureNotifier()
  let harness = VideoUploadHarness(
    configuration: VideoUploadHarness.testConfiguration(maxConcurrentParts: 2),
    failureNotifier: notifier
  )
  let record = try makeGenerationRaceRecord(harness: harness)
  try writeGenerationRaceFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.service.suspendNextSchedulePart()
  let completionCounter = GenerationRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    completionCounter.increment()
  }

  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  await harness.service.finishBackgroundEvents()
  try await waitUntil { await harness.service.schedulePartAttemptCount == 1 }

  let chunkDirectory = generationRaceChunkDirectory(record: record, harness: harness)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))
  let generation = try #require(await harness.manager.uploadGenerations[record.id])
  await harness.manager.transitionToTerminalFailure(record, generation: generation)
  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))

  await harness.service.releaseScheduledParts()
  try await waitUntil { completionCounter.value == 1 }

  let failed = try #require(try await harness.repository.fetch(id: record.id))
  #expect(failed.status == .failed)
  #expect(failed.uploadRetryCount == 0)
  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(await notifier.notifiedCounts == [1])
  #expect(await harness.service.cancelPartsCount == 1)
  #expect(await harness.service.calls.filter { $0.hasPrefix("schedule:") } == ["schedule:2"])
}

@Test func staleRecoveryLoopCannotInterfereWithImmediateRetryOfSameRecord() async throws {
  let harness = VideoUploadHarness(
    configuration: VideoUploadHarness.testConfiguration(maxConcurrentParts: 2)
  )
  let record = try makeGenerationRaceRecord(harness: harness)
  try writeGenerationRaceFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.service.suspendNextSchedulePart()
  let completionCounter = GenerationRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    completionCounter.increment()
  }

  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)
  await harness.service.finishBackgroundEvents()
  try await waitUntil { await harness.service.schedulePartAttemptCount == 1 }
  let generation = try #require(await harness.manager.uploadGenerations[record.id])
  await harness.manager.transitionToTerminalFailure(record, generation: generation)
  #expect(await harness.manager.uploadGenerations[record.id] != nil)

  await harness.service.setHangOnParts(true)
  await harness.manager.retry(attachmentID: record.id)
  try await waitUntil {
    let calls = await harness.service.calls
    let partAttempts = await harness.service.partAttempts
    return calls.filter { $0.hasPrefix("initiate:") }.count == 1
      && !partAttempts.isEmpty
  }

  await harness.service.releaseScheduledParts()
  try await waitUntil {
    let scheduledCount = await harness.service.scheduledPartIdentifiers.count
    return completionCounter.value == 1 && scheduledCount == 1
  }

  try await assertStaleBackgroundEventIsAcknowledged(recordID: record.id, harness: harness)

  let retried = try #require(try await harness.repository.fetch(id: record.id))
  let chunkDirectory = generationRaceChunkDirectory(record: record, harness: harness)
  #expect(retried.status == .uploading)
  #expect(retried.uploadRetryCount == 0)
  #expect(retried.uploadedParts.isEmpty)
  #expect(FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(await harness.service.cancelPartsCount == 2)

  await harness.manager.remove(attachmentID: record.id)
  #expect(await harness.manager.uploadGenerations[record.id] != nil)
}

@Test func uploadGenerationNeverReusesAReclaimedValue() async {
  let harness = VideoUploadHarness()
  let firstRecordID = UUID()
  let secondRecordID = UUID()

  let first = await harness.manager.advanceUploadGeneration(recordID: firstRecordID)
  await harness.manager.reclaimUploadGeneration(first, recordID: firstRecordID)
  let second = await harness.manager.advanceUploadGeneration(recordID: secondRecordID)
  let rebuilt = await harness.manager.advanceUploadGeneration(recordID: firstRecordID)

  #expect(first < second)
  #expect(second < rebuilt)
}

@Test func foregroundWriterDoesNotRecreatePartsAfterRemovalDuringUploadingSave() async throws {
  let service = MockVideoUploadService()
  let repository = GatedUploadingVideoAttachmentRepository()
  let filesDirectory = FileManager.default.temporaryDirectory.appending(
    path: "foreground-generation-race-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  let sourceURL = try makeTemporaryVideoSource()
  await repository.suspendNextUploadingSave()

  let record = try await manager.enqueue(
    sourceURL: sourceURL,
    setLogID: UUID(),
    studentID: UUID()
  )
  try await waitUntil { await repository.uploadingSaveStarted }

  let chunkDirectory = filesDirectory.appending(
    path: "\(record.id.uuidString).parts",
    directoryHint: .isDirectory
  )
  await manager.remove(attachmentID: record.id)
  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))

  await repository.releaseUploadingSave()
  try await waitUntil { await manager.activeUploads[record.id] == nil }

  #expect(!FileManager.default.fileExists(atPath: chunkDirectory.path))
  #expect(await repository.fetch(id: record.id) == nil)
  #expect(await service.calls.isEmpty)
}

private func makeGenerationRaceRecord(harness: VideoUploadHarness) throws -> VideoAttachment {
  let recordID = UUID()
  let targets = try (1...3).map { partNumber in
    VideoUploadPartTarget(
      partNumber: partNumber,
      url: try #require(URL(string: "https://oss.test/parts/\(partNumber)"))
    )
  }
  return VideoAttachment(
    id: recordID,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: harness.service.remoteAttachmentID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 2_560,
    localFileName: "\(recordID.uuidString).mp4",
    recordedAt: Date(),
    uploadPartCount: 3,
    uploadPartTargets: targets,
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")]
  )
}

private func assertStaleBackgroundEventIsAcknowledged(
  recordID: UUID,
  harness: VideoUploadHarness
) async throws {
  let staleIdentifier = try #require(await harness.service.scheduledPartIdentifiers.first)
  let currentGeneration = try #require(await harness.manager.uploadGenerations[recordID])
  #expect(staleIdentifier.generation != currentGeneration)
  let counter = GenerationRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(identifier: staleIdentifier, result: .success("stale-etag-2"))
  )
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: harness.service.backgroundSessionIdentifier
  )
  try await waitUntil { counter.value == 1 }
}

private func writeGenerationRaceFixture(
  record: VideoAttachment,
  harness: VideoUploadHarness
) throws {
  try FileManager.default.createDirectory(
    at: harness.filesDirectory,
    withIntermediateDirectories: true
  )
  let fileName = try #require(record.localFileName)
  try Data(repeating: 0xAB, count: 2_560).write(
    to: harness.filesDirectory.appending(path: fileName)
  )
}

private func generationRaceChunkDirectory(
  record: VideoAttachment,
  harness: VideoUploadHarness
) -> URL {
  harness.filesDirectory.appending(
    path: "\(record.id.uuidString).parts",
    directoryHint: .isDirectory
  )
}

private final class GenerationRaceCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int {
    lock.withLock { storage }
  }

  func increment() {
    lock.withLock { storage += 1 }
  }
}

private actor GatedUploadingVideoAttachmentRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment] = [:]
  private var shouldSuspendUploadingSave = false
  private var uploadingSaveContinuation: CheckedContinuation<Void, Never>?
  private(set) var uploadingSaveStarted = false

  func suspendNextUploadingSave() {
    shouldSuspendUploadingSave = true
  }

  func releaseUploadingSave() {
    uploadingSaveContinuation?.resume()
    uploadingSaveContinuation = nil
  }

  func save(_ attachment: VideoAttachment) async {
    storage[attachment.id] = attachment
    if shouldSuspendUploadingSave, attachment.status == .uploading {
      shouldSuspendUploadingSave = false
      uploadingSaveStarted = true
      await withCheckedContinuation { continuation in
        uploadingSaveContinuation = continuation
      }
    }
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
