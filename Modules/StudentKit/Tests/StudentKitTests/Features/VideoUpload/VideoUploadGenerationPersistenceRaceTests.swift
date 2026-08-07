import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func newerInMemoryGenerationRejectsOldEventDuringPersistence() async throws {
  let service = MockVideoUploadService()
  let record = try makeGenerationPersistenceRaceRecord(service: service)
  let repository = GatedGenerationRepository(seed: record)
  let filesDirectory = FileManager.default.temporaryDirectory.appending(
    path: "generation-persistence-race-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  try writeGenerationPersistenceRaceFixture(record: record, filesDirectory: filesDirectory)
  await repository.suspendNextGenerationSave()
  await manager.activateBackgroundHandling()

  let task = await manager.startUploadTask(
    recordID: record.id,
    sourceURL: nil,
    previousGeneration: record.uploadGeneration
  )
  try await waitUntil { await repository.generationSaveStarted }
  let newGeneration = try #require(await manager.uploadGenerations[record.id])
  let oldGeneration = try #require(record.uploadGeneration)
  #expect(newGeneration > oldGeneration)

  try await deliverOldGenerationEvent(
    recordID: record.id,
    generation: oldGeneration,
    service: service
  )

  let suspended = try #require(await repository.fetch(id: record.id))
  #expect(suspended.uploadGeneration == oldGeneration)
  #expect(suspended.uploadedParts.isEmpty)
  #expect(await manager.uploadGenerations[record.id] == newGeneration)

  await repository.releaseGenerationSave()
  await task.value

  let uploaded = try #require(await repository.fetch(id: record.id))
  #expect(uploaded.status == .uploaded)
  #expect(uploaded.uploadGeneration == nil)
  #expect(await service.calls.contains("complete:1"))
}

@Test func sessionFinishedDuringPersistenceDoesNotRollBackMemoryGeneration() async throws {
  let service = MockVideoUploadService()
  let record = try makeGenerationPersistenceRaceRecord(service: service)
  let repository = GatedGenerationRepository(seed: record)
  let filesDirectory = FileManager.default.temporaryDirectory.appending(
    path: "generation-session-finished-race-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  try writeGenerationPersistenceRaceFixture(record: record, filesDirectory: filesDirectory)
  await manager.activateBackgroundHandling()
  // Register the student as recovering so the session-finished sweep walks
  // this record. An active OS wake makes launch recovery defer ownership to
  // the background-session path instead of harvesting and restarting tasks.
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: service.backgroundSessionIdentifier
  ) {}
  await manager.recoverInterruptedUploads(studentID: record.studentID)
  #expect(await manager.activeUploads[record.id] == nil)

  await repository.suspendNextGenerationSave()
  let task = await manager.startUploadTask(
    recordID: record.id,
    sourceURL: nil,
    previousGeneration: record.uploadGeneration
  )
  try await waitUntil { await repository.generationSaveStarted }
  let newGeneration = try #require(await manager.uploadGenerations[record.id])
  let oldGeneration = try #require(record.uploadGeneration)
  #expect(newGeneration > oldGeneration)
  #expect(await repository.suspendedGeneration == newGeneration)
  #expect(await manager.activeUploads[record.id] != nil)

  try await deliverOldGenerationEvent(
    recordID: record.id,
    generation: oldGeneration,
    service: service
  )

  try await finishBackgroundEventsWithoutScheduling(
    service: service,
    manager: manager,
    recordID: record.id,
    generation: newGeneration
  )

  await repository.releaseGenerationSave()
  await task.value

  let uploaded = try #require(await repository.fetch(id: record.id))
  #expect(uploaded.status == .uploaded)
}

private func finishBackgroundEventsWithoutScheduling(
  service: MockVideoUploadService,
  manager: VideoUploadManager,
  recordID: UUID,
  generation: Int
) async throws {
  let finishCounter = GenerationPersistenceRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: service.backgroundSessionIdentifier
  ) {
    finishCounter.increment()
  }
  let scheduleCallsBeforeFinish = await service.calls.filter { $0.hasPrefix("schedule:") }
  await service.finishBackgroundEvents()
  try await waitUntil { finishCounter.value == 1 }
  #expect(await manager.uploadGenerations[recordID] == generation)
  // The dormant sweep must skip the record owned by the live pipeline task:
  // a second writer under the same generation would duplicate part PUTs.
  let scheduleCallsAfterFinish = await service.calls.filter { $0.hasPrefix("schedule:") }
  #expect(scheduleCallsAfterFinish == scheduleCallsBeforeFinish)
}

@Test func supersededWriterExitDoesNotClearNewWriterSlot() async throws {
  let service = MockVideoUploadService()
  let record = try makeGenerationPersistenceRaceRecord(service: service)
  let repository = GatedGenerationRepository(seed: record)
  let filesDirectory = FileManager.default.temporaryDirectory.appending(
    path: "ownership-slot-race-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let manager = VideoUploadManager(
    service: service,
    exporter: MockVideoExporter(),
    repository: repository,
    configuration: VideoUploadHarness.testConfiguration(),
    filesDirectory: filesDirectory
  )
  try writeGenerationPersistenceRaceFixture(record: record, filesDirectory: filesDirectory)
  await manager.activateBackgroundHandling()

  // Writer A suspends inside its generation save; writer B then supersedes it
  // and parks at part scheduling. Releasing A makes it fail its generation
  // check and exit — its clear must not evict B's registration.
  await repository.suspendNextGenerationSave()
  let taskA = await manager.startUploadTask(
    recordID: record.id,
    sourceURL: nil,
    previousGeneration: record.uploadGeneration
  )
  try await waitUntil { await repository.generationSaveStarted }
  await service.suspendNextSchedulePart()
  _ = await manager.startUploadTask(recordID: record.id, sourceURL: nil)

  await repository.releaseGenerationSave()
  await taskA.value
  #expect(await manager.activeUploads[record.id] != nil)

  await service.releaseScheduledParts()
  try await waitUntil { await manager.activeUploads[record.id] == nil }

  // The failure-task registration path shares the ownership bookkeeping:
  // it must register into the now-free slot and clear only itself.
  _ = await manager.startFailureTask(recordID: record.id, failure: .unknown)
  try await waitUntil { await manager.activeUploads[record.id] == nil }
}

private func deliverOldGenerationEvent(
  recordID: UUID,
  generation: Int,
  service: MockVideoUploadService
) async throws {
  let completionCounter = GenerationPersistenceRaceCounter()
  BackgroundUploadCompletionRegistry.shared.store(
    identifier: service.backgroundSessionIdentifier
  ) {
    completionCounter.increment()
  }
  await service.emitBackgroundEvent(
    BackgroundVideoPartEvent(
      identifier: VideoUploadPartIdentifier(
        recordID: recordID,
        partNumber: 1,
        generation: generation
      ),
      result: .success("stale-etag-1")
    )
  )
  BackgroundUploadCompletionRegistry.shared.markEventsDelivered(
    identifier: service.backgroundSessionIdentifier
  )
  try await waitUntil { completionCounter.value == 1 }
}

func makeGenerationPersistenceRaceRecord(
  service: MockVideoUploadService
) throws -> VideoAttachment {
  let recordID = UUID()
  return VideoAttachment(
    id: recordID,
    setLogID: UUID(),
    studentID: UUID(),
    remoteAttachmentID: service.remoteAttachmentID,
    status: .uploading,
    contentType: "video/mp4",
    durationSeconds: 10,
    sizeBytes: 1_024,
    localFileName: "\(recordID.uuidString).mp4",
    recordedAt: Date(),
    uploadPartCount: 1,
    uploadPartTargets: [
      VideoUploadPartTarget(
        partNumber: 1,
        url: try #require(URL(string: "https://oss.test/parts/1"))
      )
    ],
    uploadGeneration: 7
  )
}

private func writeGenerationPersistenceRaceFixture(
  record: VideoAttachment,
  filesDirectory: URL
) throws {
  try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
  let fileName = try #require(record.localFileName)
  try Data(repeating: 0xAB, count: 1_024).write(to: filesDirectory.appending(path: fileName))
}

private actor GatedGenerationRepository: VideoAttachmentRepository {
  private var storage: [UUID: VideoAttachment]
  private var shouldSuspendGenerationSave = false
  private var generationSaveContinuation: CheckedContinuation<Void, Never>?
  private(set) var generationSaveStarted = false
  private(set) var suspendedGeneration: Int?

  init(seed: VideoAttachment) {
    storage = [seed.id: seed]
  }

  func suspendNextGenerationSave() {
    shouldSuspendGenerationSave = true
  }

  func releaseGenerationSave() {
    generationSaveContinuation?.resume()
    generationSaveContinuation = nil
  }

  func save(_ attachment: VideoAttachment) async {
    if shouldSuspendGenerationSave,
      attachment.uploadGeneration != storage[attachment.id]?.uploadGeneration
    {
      shouldSuspendGenerationSave = false
      generationSaveStarted = true
      suspendedGeneration = attachment.uploadGeneration
      await withCheckedContinuation { continuation in
        generationSaveContinuation = continuation
      }
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

private final class GenerationPersistenceRaceCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}
