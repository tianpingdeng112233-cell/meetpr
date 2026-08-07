import CoreModels
import Foundation
import Testing

@testable import StudentKit

@Test func sameGenerationSiblingCallbacksCompleteAcrossSeparateWakes() async throws {
  let harness = VideoUploadHarness()
  let record = try makePersistedGenerationRecord(harness: harness, generation: 41)
  try writePersistedGenerationFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.manager.activateBackgroundHandling()

  await harness.service.setPendingParts([3])
  try await deliverWake(
    identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 41),
    harness: harness
  )
  let afterFirstWake = try #require(try await harness.repository.fetch(id: record.id))
  #expect(afterFirstWake.uploadedParts.map(\.partNumber) == [1, 2])
  #expect(afterFirstWake.uploadGeneration == 41)

  await harness.service.setPendingParts([])
  try await deliverWake(
    identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 3, generation: 41),
    harness: harness
  )
  let uploaded = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(uploaded.uploadGeneration == nil)
  #expect(await harness.service.calls.contains("complete:1,2,3"))
}

@Test func persistedGenerationRejectsOlderEventThatArrivesFirstAfterRestart() async throws {
  let harness = VideoUploadHarness()
  let record = try makePersistedGenerationRecord(harness: harness, generation: 9)
  try writePersistedGenerationFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.manager.activateBackgroundHandling()

  let staleCounter = GenerationRecoveryCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    staleCounter.increment()
  }
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 8),
      result: .success("stale-etag-2")
    )
  )
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: harness.service.backgroundSessionIdentifier
  )
  try await waitUntil { staleCounter.value == 1 }

  let unchanged = try #require(try await harness.repository.fetch(id: record.id))
  #expect(unchanged.uploadedParts.map(\.partNumber) == [1])
  #expect(unchanged.uploadGeneration == 9)

  await harness.service.setPendingParts([3])
  try await deliverWake(
    identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 9),
    harness: harness
  )
  let accepted = try #require(try await harness.repository.fetch(id: record.id))
  #expect(accepted.uploadedParts.map(\.partNumber) == [1, 2])
  #expect(accepted.uploadGeneration == 9)
}

@Test func manualRecoveryCancelsLegacyTasksAndRestartsFromPersistedRecord() async throws {
  let harness = VideoUploadHarness()
  let record = try makePersistedGenerationRecord(harness: harness, generation: nil)
  try writePersistedGenerationFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.service.setHasLegacyPendingParts(true)

  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)

  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(await harness.service.cancelPartsCount == 1)
  #expect(await harness.service.partAttempts[2] == 1)
  #expect(await harness.service.partAttempts[3] == 1)
  #expect(await harness.service.calls.allSatisfy { !$0.hasPrefix("initiate:") })
  // Generation reclamation lands in a follow-up save after the uploaded
  // status; poll for it instead of asserting inside that window.
  try await waitUntil {
    try await harness.repository.fetch(id: record.id)?.uploadGeneration == nil
  }
}

@Test func manualRecoveryHarvestsEnumeratedZombiePartsAndRestartsMissingParts() async throws {
  let harness = VideoUploadHarness()
  let record = try makePersistedGenerationRecord(harness: harness, generation: 17)
  try writePersistedGenerationFixture(record: record, harness: harness)
  try writePersistedGenerationChunks(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.service.setPendingParts([2, 3])

  await harness.manager.recoverInterruptedUploads(studentID: record.studentID)

  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(await harness.service.cancelPartsCount == 1)
  #expect(await harness.service.partAttempts[1] == nil)
  #expect(await harness.service.partAttempts[2] == 1)
  #expect(await harness.service.partAttempts[3] == 1)
  #expect(await harness.service.calls.allSatisfy { !$0.hasPrefix("initiate:") })
  try await waitUntil {
    !FileManager.default.fileExists(
      atPath: persistedGenerationChunkDirectory(record: record, harness: harness).path
    )
  }
  #expect(
    !FileManager.default.fileExists(
      atPath: persistedGenerationChunkDirectory(record: record, harness: harness).path
    )
  )
}

@Test func restoredCancellationWithoutOSHandlerDrainsAfterQuiescence() async throws {
  let harness = VideoUploadHarness()
  let record = try makePersistedGenerationRecord(harness: harness, generation: 23)
  try writePersistedGenerationFixture(record: record, harness: harness)
  try await harness.repository.save(record)
  await harness.manager.activateBackgroundHandling()

  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(recordID: record.id, partNumber: 2, generation: 23),
      result: .failure(.cancelled)
    )
  )

  _ = try await waitForStatus(harness.repository, id: record.id, oneOf: [.uploaded])
  #expect(await harness.service.cancelPartsCount == 1)
  #expect(await harness.service.partAttempts[2] == 1)
  #expect(await harness.service.partAttempts[3] == 1)
  #expect(
    await harness.manager.restoredBackgroundRecords[
      harness.service.backgroundSessionIdentifier
    ] == nil
  )
}

private func deliverWake(
  identifier: VideoUploadPartIdentifier,
  harness: VideoUploadHarness
) async throws {
  let counter = GenerationRecoveryCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: harness.service.backgroundSessionIdentifier
  ) {
    counter.increment()
  }
  await harness.service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: identifier,
      result: .success("etag-\(identifier.partNumber)")
    )
  )
  await harness.service.finishBackgroundEvents()
  try await waitUntil { counter.value == 1 }
}

private func makePersistedGenerationRecord(
  harness: VideoUploadHarness,
  generation: Int?
) throws -> VideoAttachment {
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
    uploadedParts: [VideoUploadedPart(partNumber: 1, etag: "etag-1")],
    uploadGeneration: generation
  )
}

private func writePersistedGenerationFixture(
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

private func writePersistedGenerationChunks(
  record: VideoAttachment,
  harness: VideoUploadHarness
) throws {
  let directory = persistedGenerationChunkDirectory(record: record, harness: harness)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try Data([0xAB]).write(to: directory.appending(path: "stale.chunk"))
}

private func persistedGenerationChunkDirectory(
  record: VideoAttachment,
  harness: VideoUploadHarness
) -> URL {
  harness.filesDirectory.appending(
    path: "\(record.id.uuidString).parts",
    directoryHint: .isDirectory
  )
}

private final class GenerationRecoveryCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}
